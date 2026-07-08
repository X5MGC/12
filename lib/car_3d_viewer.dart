import 'dart:convert';
import 'package:flutter/material.dart';
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
      // 等待 viewer.html 中的 JS IIFE 执行完毕（viewer.html 有 793KB，iOS 12 上 onPageFinished 可能在 JS 执行完之前触发）
      for (int i = 0; i < 20; i++) {
        try {
          final result = await _controller.runJavaScriptReturningResult(
            'typeof window.loadGLB === "function"',
          );
          if (result.toString() == 'true') break;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
      }
      // 直接让 HTML 用相对路径加载 GLB，避免传递 2.2MB base64 字符串
      await _controller.runJavaScript("loadGLB('C211.glb')");
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
