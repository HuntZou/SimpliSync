'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';
const RESOURCES = {
  "assets/AssetManifest.json": "2efbb41d7877d10aac9d091f58ccd7b9",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "95db9098c58fd6db106f1116bae85a0b",
"assets/NOTICES": "ab8d50618b854d4a94556984eec33c35",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "6d342eb68f170c97609e9da345464e5e",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/android-icon-144x144.png": "817f71e010c6d841f672b782c80cf0e1",
"icons/android-icon-192x192.png": "abe700cad9dcae302bbbcb78044c34e2",
"icons/android-icon-36x36.png": "f24cb78f4420c3987f825279e23b70f9",
"icons/android-icon-48x48.png": "5f4e8cd2ff118b4409847024bcc5ce95",
"icons/android-icon-72x72.png": "22c142dc4ddb2c98cae5683d4a049fcc",
"icons/android-icon-96x96.png": "a6ef890c03247fc48773b418450b2494",
"icons/apple-icon-114x114.png": "55d9bea392a6d19aafc09a7e67a05327",
"icons/apple-icon-120x120.png": "c341b49c2fd21aa61b6c13ae78547739",
"icons/apple-icon-144x144.png": "817f71e010c6d841f672b782c80cf0e1",
"icons/apple-icon-152x152.png": "84da25572655c5999ea26c1132a9b0ca",
"icons/apple-icon-180x180.png": "d3ccc11b03aaf6dd17356751e356d096",
"icons/apple-icon-57x57.png": "afc55340d52bdbe3a867df3cdea0cdd6",
"icons/apple-icon-60x60.png": "27388beee88d74df41f0d5ccdf3afd8a",
"icons/apple-icon-72x72.png": "22c142dc4ddb2c98cae5683d4a049fcc",
"icons/apple-icon-76x76.png": "7fa4230cca177150fefcf13e3c2784ca",
"icons/apple-icon-precomposed.png": "c7ce20e8e58917cce81e16c96306e548",
"icons/apple-icon.png": "c7ce20e8e58917cce81e16c96306e548",
"icons/browserconfig.xml": "97775b1fd3b6e6c13fc719c2c7dd0ffe",
"icons/favicon-16x16.png": "64f7bd054b73330fd9eea7d7791030f4",
"icons/favicon-32x32.png": "52f05ee2d7092f6226d86647b5a87f1b",
"icons/favicon-96x96.png": "a6ef890c03247fc48773b418450b2494",
"icons/favicon.ico": "2125323218800c5ae9c838416de1c24a",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/manifest.json": "cc33e98814ebc3215a7455f17750ff42",
"icons/ms-icon-144x144.png": "817f71e010c6d841f672b782c80cf0e1",
"icons/ms-icon-150x150.png": "ab911c70268afcf20128479172cb9633",
"icons/ms-icon-310x310.png": "b9eeadae632bf5e20ecaf2fde0b05914",
"icons/ms-icon-70x70.png": "daf3cfee3294ff40e1156407e787cf8b",
"index.html": "61f86db56d4769006fe7006facfbce94",
"/": "61f86db56d4769006fe7006facfbce94",
"main.dart.js": "cc4cdcba58405ca3bfccff978e59f41c",
"manifest.json": "75c505aba4e924b7680ae567a532d192",
"version.json": "44dbbc055edbe3ddc1c994d64d00dcc6"
};

// The application shell files that are downloaded before a service worker can
// start.
const CORE = [
  "main.dart.js",
"index.html",
"assets/NOTICES",
"assets/AssetManifest.json",
"assets/FontManifest.json"];
// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});

// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});

// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache.
        return response || fetch(event.request).then((response) => {
          cache.put(event.request, response.clone());
          return response;
        });
      })
    })
  );
});

self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});

// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}

// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
