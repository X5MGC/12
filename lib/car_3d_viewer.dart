import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Car3DViewer extends StatefulWidget {
  final void Function(bool isTopView)? onToggleView;

  const Car3DViewer({super.key, this.onToggleView});

  @override
  Car3DViewerState createState() => Car3DViewerState();
}

class Car3DViewerState extends State<Car3DViewer> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('WebView page finished: $url');
            _loadModel();
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (message) {
          debugPrint('JS Channel: ${message.message}');
          if (message.message == 'loaded') {
            if (mounted) setState(() => _loaded = true);
          } else if (message.message == 'topView') {
            widget.onToggleView?.call(true);
          } else if (message.message == 'normalView') {
            widget.onToggleView?.call(false);
          }
        },
      )
      ..loadFlutterAsset('assets/3D/viewer.html');
  }

  /// 从外部切换视图（如详情页返回时重置为普通视角）
  void toggleTopView() {
    _controller.runJavaScript('window.toggleTopView && window.toggleTopView()');
  }

  /// 同步车辆状态数据到3D模型，驱动车门/车窗/天窗/尾箱动画
  void updateBodyStatus(Map<String, dynamic> vehicleData) {
    if (!_loaded) return;
    final json = jsonEncode(vehicleData);
    _controller.runJavaScript(
        "window.setVehicleData && window.setVehicleData('$json')");
  }

  Future<void> _loadModel() async {
    try {
      debugPrint('Loading GLB...');
      final data = await rootBundle.load('assets/3D/C211.glb');
      final bytes = data.buffer.asUint8List();
      debugPrint('GLB size: ${bytes.length}');
      final b64 = base64Encode(bytes);
      debugPrint('Base64 size: ${b64.length}');
      await _controller.runJavaScript("loadGLB('${b64}')");
      debugPrint('loadGLB called');
    } catch (e) {
      debugPrint('Error loading GLB: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_loaded)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
          ),
      ],
    );
  }
}
