-- Shared album for the page: photos, notes, lists. Already applied to the Supabase
-- project "tempo"; kept here as the record. Safe to re-run in the SQL editor.
--
-- Same model as the step counter: RLS on, no table grants, and the only way in
-- is through the lilac_* functions below, each of which checks the page secret.
-- The value in lilac_ok() is the sha256 of that secret, not the secret itself.

create table if not exists public.lilac_items (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null,
  parent     uuid references public.lilac_items(id) on delete cascade,
  who        text not null check (who in ('g', 'c')),
  data       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists lilac_items_kind_idx on public.lilac_items (kind, created_at desc);
create index if not exists lilac_items_parent_idx on public.lilac_items (parent);

create table if not exists public.lilac_blobs (
  item_id uuid primary key references public.lilac_items(id) on delete cascade,
  thumb   text,
  body    text
);

alter table public.lilac_items enable row level security;
alter table public.lilac_blobs enable row level security;
revoke all on public.lilac_items from anon, authenticated;
revoke all on public.lilac_blobs from anon, authenticated;

create or replace function public.lilac_ok(p_secret text)
returns boolean language sql immutable set search_path = public, pg_catalog as $$
  select encode(sha256(convert_to(coalesce(p_secret, ''), 'UTF8')), 'hex')
       = 'e1724c2acfde35f1f759167308103e6171946ab4d5430241c1becdd0a0ddd800';
$$;

-- One row as the page sees it. Two things stay hidden until they're earned:
--   * an answer to the daily question, until the reader has answered that day too
--   * a letter with an "open on" date, until that date (except for its author)
create or replace function public.lilac_view(i public.lilac_items, p_who text)
returns jsonb language sql stable set search_path = public, pg_catalog as $$
  select jsonb_build_object(
    'id', i.id, 'kind', i.kind, 'parent', i.parent, 'who', i.who,
    'at', i.created_at, 'upd', i.updated_at,
    'photo', exists (select 1 from lilac_blobs b where b.item_id = i.id and b.body is not null),
    'data', case
      when i.kind = 'answer' and i.who <> p_who and not exists (
        select 1 from lilac_items m
        where m.kind = 'answer' and m.who = p_who and m.data->>'day' = i.data->>'day'
      ) then (i.data - 'text') || '{"hidden":true}'::jsonb
      when i.kind = 'letter' and i.who <> p_who and (i.data->>'unlock') is not null
        and (i.data->>'unlock') > to_char(now() at time zone 'UTC' + interval '14 hours', 'YYYY-MM-DD')
        then (i.data - 'body') || '{"hidden":true}'::jsonb
      else i.data
    end);
$$;

create or replace function public.lilac_list(secret text, who text)
returns jsonb language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  if not lilac_ok(secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(
    'now', now(),
    'items', coalesce((select jsonb_agg(lilac_view(i, lilac_list.who) order by i.created_at desc) from lilac_items i
      where i.kind <> 'ping' or i.created_at > now() - interval '3 days'), '[]'::jsonb));
end $$;

-- Create (id null or unknown) or update (id known). On update, kind/parent/who
-- are kept; data is replaced; thumb/body are replaced only when given.
create or replace function public.lilac_put(
  secret text, who text, kind text, id uuid default null, parent uuid default null,
  data jsonb default '{}'::jsonb, thumb text default null, body text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions, pg_catalog as $$
declare
  v_id uuid := id;
  row  lilac_items;
begin
  if not lilac_ok(secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  if who not in ('g', 'c') then raise exception 'bad who'; end if;
  if kind not in ('bouquet', 'flower', 'selfie', 'letter', 'date', 'answer', 'place', 'song', 'event', 'ping')
    then raise exception 'bad kind'; end if;
  if length(data::text) > 12000 then raise exception 'data too big'; end if;
  if length(coalesce(thumb, '')) > 60000 then raise exception 'thumb too big'; end if;
  if length(coalesce(body, '')) > 1500000 then raise exception 'photo too big'; end if;

  if v_id is not null and exists (select 1 from lilac_items x where x.id = v_id) then
    update lilac_items x set data = lilac_put.data, updated_at = now() where x.id = v_id returning x.* into row;
  else
    if (select count(*) from lilac_items) >= 20000 then raise exception 'album full'; end if;
    if kind = 'ping' then
      delete from lilac_items x where x.kind = 'ping' and x.created_at < now() - interval '60 days';
    end if;
    if kind = 'answer' and exists (
      select 1 from lilac_items x
      where x.kind = 'answer' and x.who = lilac_put.who and x.data->>'day' = lilac_put.data->>'day')
      then raise exception 'already answered'; end if;
    insert into lilac_items (id, kind, parent, who, data)
      values (coalesce(v_id, gen_random_uuid()), kind, parent, who, data) returning * into row;
  end if;

  -- A "thinking of you" heart from her emails Caio through the same notifier the
  -- step counter uses (at most one email every ten minutes).
  if kind = 'ping' and who = 'g' and not exists (
    select 1 from lilac_items x where x.kind = 'ping' and x.who = 'g' and x.id <> row.id
      and x.created_at > now() - interval '10 minutes') then
    begin
      perform net.http_post(
        url := (select v from lilac_config where k = 'notify_url'),
        body := jsonb_build_object(
          'key', (select v from lilac_config where k = 'notify_key'),
          'steps', (select total from lilac_steps where id = 'gabi'),
          'delta', 0, 'milestone', 0, 'ping', true,
          'note', 'She tapped the heart: thinking of you'),
        headers := '{"Content-Type": "application/json"}'::jsonb)
      where exists (select 1 from lilac_config where k = 'notify_url');
    exception when others then null;
    end;
  end if;

  if thumb is not null or body is not null then
    insert into lilac_blobs (item_id, thumb, body) values (row.id, thumb, body)
    on conflict (item_id) do update
      set thumb = coalesce(excluded.thumb, lilac_blobs.thumb), body = coalesce(excluded.body, lilac_blobs.body);
  end if;
  return lilac_view(row, who);
end $$;

create or replace function public.lilac_del(secret text, id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  if not lilac_ok(secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  delete from lilac_items x where x.id = lilac_del.id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.lilac_thumbs(secret text, ids uuid[])
returns jsonb language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  if not lilac_ok(secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  if coalesce(array_length(ids, 1), 0) > 80 then raise exception 'too many'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', b.item_id, 'thumb', b.thumb))
                   from lilac_blobs b where b.item_id = any(ids)), '[]'::jsonb);
end $$;

create or replace function public.lilac_blob(secret text, id uuid)
returns text language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  if not lilac_ok(secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  return (select b.body from lilac_blobs b where b.item_id = lilac_blob.id);
end $$;

revoke all on function public.lilac_ok(text), public.lilac_view(public.lilac_items, text) from public, anon, authenticated;
revoke all on function public.lilac_list(text, text), public.lilac_put(text, text, text, uuid, uuid, jsonb, text, text),
  public.lilac_del(text, uuid), public.lilac_thumbs(text, uuid[]), public.lilac_blob(text, uuid) from public;
grant execute on function public.lilac_list(text, text), public.lilac_put(text, text, text, uuid, uuid, jsonb, text, text),
  public.lilac_del(text, uuid), public.lilac_thumbs(text, uuid[]), public.lilac_blob(text, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
