{{flutter_js}}
{{flutter_build_config}}

// Load CanvasKit from the local build instead of the gstatic CDN so the app
// works offline / on restricted networks during the demo.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/"
  }
});
