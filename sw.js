// Shows push notifications for this page. It holds no content of its own:
// the text arrives encrypted inside each push message.
self.addEventListener("install", function () { self.skipWaiting(); });
self.addEventListener("activate", function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener("push", function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { body: e.data ? e.data.text() : "" }; }
  e.waitUntil(self.registration.showNotification(d.title || "Lilac", {
    body: d.body || "",
    tag: d.tag || "lilac",
    renotify: true,
    icon: "icon-192.png",
    badge: "icon-192.png",
    data: { url: d.url || self.registration.scope }
  }));
});

self.addEventListener("notificationclick", function (e) {
  e.notification.close();
  var url = (e.notification.data && e.notification.data.url) || self.registration.scope;
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) {
      var c = list[i];
      if (c.url.indexOf(self.registration.scope) === 0 && "focus" in c) {
        return c.focus().then(function (w) { return w && w.navigate ? w.navigate(url).catch(function () {}) : null; });
      }
    }
    return self.clients.openWindow(url);
  }));
});
