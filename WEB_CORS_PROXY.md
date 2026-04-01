# Web CORS Proxy

The browser error means the backend at `https://schoolmanagement.canadacentral.cloudapp.azure.com` is not allowing cross-origin requests from your Flutter web dev origin such as `http://localhost:63632`.

Flutter code cannot disable browser CORS checks. For local web development, run the included proxy and point the app at it.

## 1. Start the proxy

```powershell
C:\flutter\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool\dev_api_proxy.dart
```

If `dart run` is blocked by local telemetry permissions, use:

```powershell
C:\flutter\src\flutter\bin\cache\dart-sdk\bin\dart.exe --disable-dart-dev tool\dev_api_proxy.dart
```

Optional overrides:

```powershell
C:\flutter\src\flutter\bin\cache\dart-sdk\bin\dart.exe run ^
  --define=PROXY_HOST=127.0.0.1 ^
  --define=PROXY_PORT=8081 ^
  --define=BACKEND_ORIGIN=https://schoolmanagement.canadacentral.cloudapp.azure.com ^
  tool\dev_api_proxy.dart
```

## 2. Run Flutter web

When the app is opened from `localhost`, it now defaults to `http://127.0.0.1:8081` automatically for local web development.

So once the proxy is running, this is usually enough:

```powershell
flutter run -d chrome
```

You can still force the values explicitly if you want:

```powershell
flutter run -d chrome `
  --dart-define=SERVER_ORIGIN=http://127.0.0.1:8081 `
  --dart-define=API_BASE_URL=http://127.0.0.1:8081/api
```

## 3. Production fix

The permanent fix is still on the backend:

- Return `Access-Control-Allow-Origin` for the web app origin.
- Return `Access-Control-Allow-Methods` and `Access-Control-Allow-Headers` for the preflight `OPTIONS` request.
- Apply that CORS policy to login and every authenticated API route.
