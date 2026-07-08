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
      // 等待 viewer.html JS IIFE 执行完毕（793KB，iOS 12 上 onPageFinished 可能在 JS 执行完之前触发）
      for (int i = 0; i < 20; i++) {
        try {
          final result = await _controller.runJavaScriptReturningResult(
            'typeof window.appendChunk === "function"',
          );
          if (result.toString() == 'true') break;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
      }
      // 读取 GLB 文件并 base64 编码
      final data = await rootBundle.load('assets/3D/C211.glb');
      final bytes = data.buffer.asUint8List();
      debugPrint('GLB size: ${bytes.length}');
      final b64 = base64Encode(bytes);
      debugPrint('Base64 size: ${b64.length}');
      // 分块传递（iOS 12 单次 JS 调用字符串有大小限制）
      const chunkSize = 100 * 1024; // 100KB per chunk
      for (int offset = 0; offset < b64.length; offset += chunkSize) {
        final end = (offset + chunkSize < b64.length)
            ? offset + chunkSize
            : b64.length;
        final chunk = b64.substring(offset, end);
        await _controller
            .runJavaScript("appendChunk('$chunk')");
      }
      debugPrint('All chunks sent, calling finishLoadGLB');
      await _controller.runJavaScript('finishLoadGLB()');
      debugPrint('finishLoadGLB called');
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
