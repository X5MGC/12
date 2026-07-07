import 'package:flutter/material.dart';

/// 车辆详情数据面板（可滑动），3D模型点击进入
/// 底部面板布局：上方透明，下方显示数据
class VehicleDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const VehicleDetailPage({super.key, required this.data});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Map<String, dynamic> get d => widget.data;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 点击上方透明区域（模型区域）关闭详情页
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // 底部详情面板
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xCC1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽条
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 页面内容
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.27,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: [
                        _buildPage1(), // 车身状态
                        _buildPage2(), // 系统状态
                        _buildPage3(), // 油量油耗里程
                        _buildPage4(), // 其他信息
                      ],
                    ),
                  ),
                  // 分页指示器
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        return GestureDetector(
                          onTap: () => _pageController.animateToPage(i,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                          child: Container(
                            width: i == _currentPage ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? const Color(0xFF1E88E5)
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page 1: 车身状态 ───
  Widget _buildPage1() {
    final locks = [d['driverDoorLock'], d['passengerDoorLock'], d['leftRearDoorLock'], d['rightRearDoorLock']];
    final lockOpen = locks.any((v) => v == 1);

    final doors = [d['leftFrontDoor'], d['rightFrontDoor'], d['leftRearDoor'], d['rightRearDoor']];
    final doorOpen = doors.any((v) => v == 1);

    final windows = [d['diverWindow'], d['passengerWindow'], d['leftRearWindow'], d['rightRearWindow']];
    final windowOpen = windows.any((v) => v == 1);

    final sunroofOpen = d['sunroof'] == 1;
    final trunkOpen = d['trunk'] == 1;

    final lights = [d['lowBeam'], d['highBeam'], d['frontFogLight'], d['rearFogLight'], d['positionLight']];
    final lightOn = lights.any((v) => v == 1);

    return _buildGrid([
      _DetailItem('车锁', lockOpen ? '已解锁' : '已上锁', !lockOpen),
      _DetailItem('车门', doorOpen ? '未关' : '已关', !doorOpen),
      _DetailItem('车窗', windowOpen ? '未关' : '已关', !windowOpen),
      _DetailItem('天窗', sunroofOpen ? '已开' : '已关', !sunroofOpen),
      _DetailItem('后备箱', trunkOpen ? '已开' : '已关', !trunkOpen),
      _DetailItem('车灯', lightOn ? '已开' : '已关', !lightOn),
    ]);
  }

  // ─── Page 2: 系统状态 ───
  Widget _buildPage2() {
    final airOn = d['airStatus'] == 1;
    final engineOn = d['engineStatus'] == 1 || d['engineStatus'] == 2;
    final batteryOk = d['powerBatteryStatus'] == 0;
    final voltage = (d['batteryVoltage'] ?? 0).toString();

    final systems = [d['absStatus'], d['engineSystemStatus'], d['transmissionSystemStatus'], d['airbagSystemStatus']];
    final systemOk = systems.every((v) => v == 0);

    final envTemp = (d['environmentalTemp'] ?? 0).toString();

    return _buildGrid([
      _DetailItem('空调', airOn ? '已开' : '已关', airOn),
      _DetailItem('发动机', engineOn ? '运行中' : '已熄火', engineOn),
      _DetailItem('动力电池', batteryOk ? '正常' : '异常', batteryOk),
      _DetailItem('蓄电池', '$voltage V', true),
      _DetailItem('系统故障', systemOk ? '正常' : '异常', systemOk),
      _DetailItem('环境温度', '$envTemp ℃', true),
    ]);
  }

  // ─── Page 3: 油量油耗里程 ───
  Widget _buildPage3() {
    final fuel = (d['fuelLeftover'] ?? d['remainingFuel'] ?? 0).toString();
    final range = (d['remainedOilMile'] ?? 0).toString();
    final consumption = (d['fuelConsumption100km'] ?? 0).toString();
    final totalOil = (d['igniteCumulativeOil'] ?? 0).toString();
    final odometer = (d['totalOdometer'] ?? 0).toString();
    final trip = (d['igniteCumulativeMileage'] ?? 0).toString();

    return _buildGrid([
      _DetailItem('剩余油量', '$fuel L', true),
      _DetailItem('续航里程', '$range km', true),
      _DetailItem('平均油耗', '$consumption L/100km', true),
      _DetailItem('累计油耗', '$totalOil L', true),
      _DetailItem('总里程', '$odometer km', true),
      _DetailItem('小计里程', '$trip km', true),
    ]);
  }

  // ─── Page 4: 其他信息 ───
  Widget _buildPage4() {
    final speed = (d['vehicleSpeed'] ?? d['speed'] ?? 0).toString();
    final rpmVal = d['engineSpeed'];
    final rpm = (rpmVal == 65535 || rpmVal == null) ? '--' : rpmVal.toString();
    final waterTemp = (d['engineWaterTemp'] ?? 0).toString();
    final voltage = (d['batteryVoltage'] ?? 0).toString();
    final altitude = (d['alti'] ?? 0).toString();
    final signal = (d['signaIntensity'] ?? d['networkType'] ?? 0).toString();

    return _buildGrid([
      _DetailItem('车速', '$speed km/h', true),
      _DetailItem('转速', '$rpm rpm', true),
      _DetailItem('水温', '$waterTemp ℃', true),
      _DetailItem('电压', '$voltage V', true),
      _DetailItem('海拔', '$altitude m', true),
      _DetailItem('信号强度', '$signal%', true),
    ]);
  }

  Widget _buildGrid(List<_DetailItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          final w = (MediaQuery.of(context).size.width - 60) / 2;
          return Container(
            width: w,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7D8A95))),
                const SizedBox(height: 6),
                Text(item.value,
                    style: TextStyle(
                      fontSize: 16,
                      color: item.isNormal ? Colors.white : const Color(0xFFFF5252),
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  final bool isNormal;
  _DetailItem(this.label, this.value, this.isNormal);
}
