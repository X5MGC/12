import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ACControlPage extends StatefulWidget {
  final ApiService api;
  final int vehicleTemp;
  final int envTemp;
  final bool isOn;
  final int setTemp;
  // 首页轮询回调，注册后首页每次轮询会推送最新数据
  final void Function(void Function(Map<String, dynamic> data))?
      onRegisterUpdate;

  const ACControlPage({
    super.key,
    required this.api,
    required this.vehicleTemp,
    required this.envTemp,
    required this.isOn,
    required this.setTemp,
    this.onRegisterUpdate,
  });

  @override
  State<ACControlPage> createState() => _ACControlPageState();
}

class _ACControlPageState extends State<ACControlPage> {
  late int _temperature;
  late bool _isOn;
  late int _vehicleTemp;
  late int _envTemp;
  int _windPower = 7; // 1~7档
  Timer? _debounceTimer;
  bool _loading = false;
  // 期望状态（与首页控制按钮一致的逻辑）
  bool? _expectedOn;

  @override
  void initState() {
    super.initState();
    _temperature = widget.setTemp;
    _isOn = widget.isOn;
    _vehicleTemp = widget.vehicleTemp;
    _envTemp = widget.envTemp;
    // 注册轮询更新回调
    widget.onRegisterUpdate?.call(_onPollingUpdate);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 首页5秒轮询推送到此，与首页控制按钮逻辑一致
  void _onPollingUpdate(Map<String, dynamic> d) {
    if (!mounted) return;
    final newOn = d['airStatus'] == 1;
    final newVehicleTemp = (d['vehicleTemperature'] ?? 0).round();
    final newEnvTemp = (d['environmentalTemp'] ?? 0).round();
    final setTemp = d['airConditioningSetTemperature'];

    setState(() {
      _vehicleTemp = newVehicleTemp;
      _envTemp = newEnvTemp;
      // 期望状态逻辑：发送命令后等轮询确认，确认后清除期望
      if (_expectedOn != null) {
        if (newOn == _expectedOn) {
          _expectedOn = null; // 服务端已同步
        }
        // 还没同步，保持期望状态不变
      } else {
        _isOn = newOn;
      }
      if (setTemp != null) _temperature = (setTemp as num).round();
    });
  }

  void _onTempChange(int delta) {
    setState(() {
      _temperature = (_temperature + delta).clamp(16, 32);
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final resp = await widget.api.executeCommand('openair', extraParams: {
        'temperature': _temperature,
        'windPower': _windPower,
        'airModel': 0,
      });
      if (resp.code == 0) {
        _showSnackBar('温度已设置 $_temperature°');
      } else {
        _showSnackBar('调温失败: ${resp.msg}');
      }
    });
  }

  void _onWindPowerChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final resp = await widget.api.executeCommand('openair', extraParams: {
        'temperature': _temperature,
        'windPower': _windPower,
        'airModel': 0,
      });
      if (resp.code == 0) {
        _showSnackBar('风档已设置 $_windPower');
      } else {
        _showSnackBar('设置失败: ${resp.msg}');
      }
    });
  }

  Future<void> _togglePower() async {
    setState(() => _loading = true);
    final cmd = _isOn ? 'closeair' : 'openair';
    _showSnackBar('指令发送中...');
    final resp = await widget.api.executeCommand(cmd);
    if (resp.code == 0) {
      final expectedOn = !_isOn;
      _expectedOn = expectedOn;
      setState(() => _isOn = expectedOn);
      _showSnackBar(expectedOn ? '空调已开启' : '空调已关闭');
    } else {
      _showSnackBar('操作失败: ${resp.msg}');
    }
    setState(() => _loading = false);
  }

  Future<void> _setMode(String mode) async {
    int temp;
    String msg;
    if (mode == 'summer') {
      temp = 18;
      msg = '夏季模式已开启';
    } else {
      temp = 32;
      msg = '冬季模式已开启';
    }
    setState(() {
      _loading = true;
      _temperature = temp;
    });
    final resp = await widget.api.executeCommand('openair', extraParams: {
      'temperature': temp,
      'windPower': 7,
      'airModel': 0,
    });
    if (resp.code == 0) {
      _showSnackBar(msg);
    } else {
      _showSnackBar('操作失败: ${resp.msg}');
    }
    setState(() => _loading = false);
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景图（向上偏移60px，与demo一致）
          Positioned(
            left: 0,
            top: -60,
            right: 0,
            child: Image.asset(
              'assets/images/airbg.webp',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          // 返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          // 底部控制面板
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Column(
              children: [
                // 温度控制卡片
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF28293D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    children: [
                      // 温度 ± 按钮
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 减温按钮
                            GestureDetector(
                              onTap: () => _onTempChange(-1),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2B3136),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('−',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,)),
                                ),
                              ),
                            ),
                            // 温度显示
                            Expanded(
                              child: Column(
                                children: [
                                  Text('$_temperature°',
                                      style: const TextStyle(
                                          fontSize: 48,
                                          color: Colors.white)),
                                  const Text('预设温度',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF7D8A95))),
                                ],
                              ),
                            ),
                            // 升温按钮
                            GestureDetector(
                              onTap: () => _onTempChange(1),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2B3136),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('+',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 28)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 风档滑轨
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('风档',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7D8A95))),
                                Text('$_windPower',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: const Color(0xFF5B7CF7),
                                inactiveTrackColor: const Color(0xFF3A3F4E),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                                trackHeight: 4,
                                overlayShape: SliderComponentShape.noOverlay,
                                tickMarkShape: SliderTickMarkShape.noTickMark,
                              ),
                              child: Slider(
                                min: 1,
                                max: 7,
                                divisions: 6,
                                value: _windPower.toDouble(),
                                onChanged: (v) {
                                  final newWind = v.round();
                                  if (newWind != _windPower) {
                                    setState(() => _windPower = newWind);
                                    _onWindPowerChange();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 分隔线
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.1),
                        margin: const EdgeInsets.only(bottom: 20),
                      ),
                      // 车内/车外温度 + 电源按钮
                      Row(
                        children: [
                          // 车内温度
                          Expanded(
                            child: Column(
                              children: [
                                const Text('车内温度',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7D8A95))),
                                const SizedBox(height: 4),
                                Text('$_vehicleTemp°',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                          // 电源按钮
                          GestureDetector(
                            onTap: _loading ? null : _togglePower,
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: _loading
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : Image.asset(
                                      _isOn
                                          ? 'assets/images/icons/changan/air-open.png'
                                          : 'assets/images/icons/changan/air-close.png',
                                      width: 28,
                                      height: 28,
                                    ),
                            ),
                          ),
                          // 车外温度
                          Expanded(
                            child: Column(
                              children: [
                                const Text('车外温度',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7D8A95))),
                                const SizedBox(height: 4),
                                Text('$_envTemp°',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 模式按钮卡片
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF28293D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 夏季模式
                      GestureDetector(
                        onTap: _loading ? null : () => _setMode('summer'),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2B3136),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/icons/changan/snow.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                      // 冬季模式
                      GestureDetector(
                        onTap: _loading ? null : () => _setMode('winter'),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2B3136),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/icons/changan/sun.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
