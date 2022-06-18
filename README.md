# SimpliSync

Sync your text with mutiple platform.

github page release:

- Step 1:
> Modify source code.
- Step 2:
> Run `flutter run -d edge` for test.
- Step 3:
> Run `flutter build web`.
> Or `flutter build web --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://simplisync.oss-cn-beijing.aliyuncs.com/cdn/ --release` for performance. since sources(canvaskit.wasm & canvaskit.js) loaded from oversea by default.
- Step 4:
> Copy all files from `build/web/` to `docs/`, where gitpage used.
- Step 5:
> Commit and push.

note:
for resources 404 issue, there is 2 way should be modifed:
1. /SimpliSync/web/index.html:
	```
	<base href="./">
	```
2. /SimpliSync/web/manifest.json
	```
	"start_url": "./"
	```

E-mail: zouheng613@163.com