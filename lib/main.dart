import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:webview_flutter/webview_flutter.dart';

import 'package:dio/dio.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_eado/car_3d_viewer.dart';

import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';

import 'ac_control_page.dart';

import 'vehicle_detail_page.dart';



void main() {

  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(

    statusBarColor: Colors.transparent,

    statusBarIconBrightness: Brightness.light,

    systemNavigationBarColor: Colors.transparent,

    systemNavigationBarIconBrightness: Brightness.light,

    systemNavigationBarDividerColor: Colors.transparent,

  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  ApiService().init();

  runApp(const MyApp());

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'MyEADO',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        brightness: Brightness.dark,

        primaryColor: const Color(0xFF1E88E5),

        scaffoldBackgroundColor: const Color(0xFF0A0A0A),

        colorScheme: const ColorScheme.dark(

          primary: Color(0xFF1E88E5),

          secondary: Color(0xFF1E88E5),

          surface: Color(0xFF1A1A1A),

        ),

        textTheme: ThemeData.dark().textTheme.apply(

              fontFamily: 'MiSans',

            ),

        useMaterial3: true,

      ),

      home: const LoginPage(),

    );

  }

}

class _TopNotification extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopNotification({required this.message, required this.onDismiss});

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding + 8, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xCC2A3038), Color(0xCC1E2429)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x33FFFFFF),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class LoginPage extends StatefulWidget {

  const LoginPage({super.key});



  @override

  State<LoginPage> createState() => _LoginPageState();

}



class _LoginPageState extends State<LoginPage> {

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _codeController = TextEditingController();

  final ApiService _api = ApiService();



  bool _isCountingDown = false;

  int _countdown = 60;

  Timer? _timer;

  bool _isPhoneValid = false;

  bool _isCodeValid = false;

  bool _isLoading = false;

  bool _isCheckingLogin = true;



  @override

  void initState() {

    super.initState();

    _phoneController.addListener(_validatePhone);

    _codeController.addListener(_validateCode);

    _checkLoginState();

  }



  Future<void> _checkLoginState() async {

    await _api.loadTokens();

    if (_api.isLoggedIn) {

      _goToHome();

      return;

    }

    // 尝试刷新token

    final refreshed = await _api.refreshToken();

    if (refreshed) {

      _goToHome();

      return;

    }

    setState(() {

      _isCheckingLogin = false;

    });

  }



  void _goToHome() {

    Navigator.of(context).pushReplacement(

      MaterialPageRoute(builder: (_) => const HomePage()),

    );

  }



  @override

  void dispose() {

    _timer?.cancel();

    _phoneController.dispose();

    _codeController.dispose();

    super.dispose();

  }



  void _validatePhone() {

    final phone = _phoneController.text;

    setState(() {

      _isPhoneValid =

          phone.length == 11 && RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);

    });

  }



  void _validateCode() {

    final code = _codeController.text;

    setState(() {

      _isCodeValid = code.length == 6;

    });

  }



  Future<void> _sendCode() async {

    if (!_isPhoneValid || _isCountingDown) return;



    setState(() {

      _isLoading = true;

    });



    final resp = await _api.sendSmsCode(_phoneController.text);



    setState(() {

      _isLoading = false;

    });



    if (resp.code == 0) {

      setState(() {

        _isCountingDown = true;

        _countdown = 60;

      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {

        setState(() {

          if (_countdown > 0) {

            _countdown--;

          } else {

            _isCountingDown = false;

            timer.cancel();

          }

        });

      });

      _showSnackBar('验证码已发送', const Color(0xFF1E88E5));

    } else {

      _showSnackBar(resp.msg ?? '发送失败，请稍后重试', const Color(0xFFFF5252));

    }

  }



  Future<void> _login() async {

    if (!_isPhoneValid || !_isCodeValid || _isLoading) return;



    setState(() {

      _isLoading = true;

    });



    final resp = await _api.login(_phoneController.text, _codeController.text);



    setState(() {

      _isLoading = false;

    });



    if (resp.code == 0 && resp.data != null) {

      _showSnackBar('登录成功', const Color(0xFF4CAF50));

      // 获取车辆信息并保存carId

      final carsResp = await _api.getUserCars();

      if (carsResp.code == 0 && carsResp.data != null) {

        final cars = carsResp.data;

        if (cars is List && cars.isNotEmpty && cars[0]['carId'] != null) {

          final carId = cars[0]['carId'].toString();

          _api.setCarId(carId);

          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('carId', carId);

        }

      }

      _goToHome();

    } else {

      _showSnackBar(resp.msg ?? '验证码错误', const Color(0xFFFF5252));

    }

  }



  void _showSnackBar(String message, Color color) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

        backgroundColor: color,

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    if (_isCheckingLogin) {

      return const Scaffold(

        body: Center(

          child: CircularProgressIndicator(

            color: Color(0xFF1E88E5),

          ),

        ),

      );

    }



    final size = MediaQuery.of(context).size;



    return Scaffold(

      body: SizedBox(

        width: size.width,

        height: size.height,

        child: Stack(

          children: [

            // 背景?
            Image.asset(

              'assets/images/BG.webp',

              width: size.width,

              height: size.height,

              fit: BoxFit.fill,

            ),

            // 半透明遮罩

            Container(

              width: size.width,

              height: size.height,

              color: Colors.black.withValues(alpha: 0.6),

            ),

            // 内容

            SafeArea(

              child: SingleChildScrollView(

                padding: const EdgeInsets.symmetric(horizontal: 32.0),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    const SizedBox(height: 80),



                    // Logo区域

                    Center(

                      child: Container(

                        width: 100,

                        height: 100,

                        decoration: BoxDecoration(

                          color: const Color(0xFF1E88E5).withValues(alpha: 0.1),

                          borderRadius: BorderRadius.circular(24),

                        ),

                        child: const Icon(

                          Icons.directions_car,

                          size: 56,

                          color: Color(0xFF1E88E5),

                        ),

                      ),

                    ),

                    const SizedBox(height: 24),



                    // 标题

                    const Center(

                      child: Text(

                        'MyEADO',

                        style: TextStyle(

                          fontSize: 32,

                          color: Colors.white,

                        ),

                      ),

                    ),

                    const SizedBox(height: 8),



                    // 副标?
                    const Center(

                      child: Text(

                        '智能控车，随心所驭',

                        style: TextStyle(

                          fontSize: 16,

                          color: Color(0xFF9E9E9E),

                        ),

                      ),

                    ),

                    const SizedBox(height: 60),



                    // 手机号输入框

                    Container(

                      decoration: BoxDecoration(

                        color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(

                          color: _phoneController.text.isNotEmpty

                              ? (_isPhoneValid

                                  ? const Color(0xFF4CAF50)

                                  : const Color(0xFFFF5252))

                              : const Color(0xFF333333),

                          width: 1.5,

                        ),

                      ),

                      child: Row(

                        children: [

                          const Padding(

                            padding: EdgeInsets.only(left: 16),

                            child: Icon(

                              Icons.phone_android,

                              color: Color(0xFF9E9E9E),

                              size: 22,

                            ),

                          ),

                          const SizedBox(width: 12),

                          Expanded(

                            child: TextField(

                              controller: _phoneController,

                              keyboardType: TextInputType.phone,

                              inputFormatters: [

                                FilteringTextInputFormatter.digitsOnly,

                                LengthLimitingTextInputFormatter(11),

                              ],

                              style: const TextStyle(

                                fontSize: 18,

                                color: Colors.white,

                                letterSpacing: 2,

                              ),

                              decoration: const InputDecoration(

                                hintText: '请输入手机号',

                                hintStyle: TextStyle(

                                  color: Color(0xFF666666),

                                  fontSize: 16,

                                  letterSpacing: 0,

                                ),

                                border: InputBorder.none,

                                contentPadding:

                                    EdgeInsets.symmetric(vertical: 16),

                              ),

                            ),

                          ),

                          if (_phoneController.text.isNotEmpty)

                            Padding(

                              padding: const EdgeInsets.only(right: 8),

                              child: GestureDetector(

                                onTap: () {

                                  _phoneController.clear();

                                },

                                child: const Icon(

                                  Icons.cancel,

                                  color: Color(0xFF666666),

                                  size: 20,

                                ),

                              ),

                            ),

                        ],

                      ),

                    ),

                    const SizedBox(height: 16),



                    // 验证码输入框

                    Container(

                      decoration: BoxDecoration(

                        color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(

                          color: _codeController.text.isNotEmpty

                              ? (_isCodeValid

                                  ? const Color(0xFF4CAF50)

                                  : const Color(0xFFFF5252))

                              : const Color(0xFF333333),

                          width: 1.5,

                        ),

                      ),

                      child: Row(

                        children: [

                          const Padding(

                            padding: EdgeInsets.only(left: 16),

                            child: Icon(

                              Icons.lock_outline,

                              color: Color(0xFF9E9E9E),

                              size: 22,

                            ),

                          ),

                          const SizedBox(width: 12),

                          Expanded(

                            child: TextField(

                              controller: _codeController,

                              keyboardType: TextInputType.number,

                              inputFormatters: [

                                FilteringTextInputFormatter.digitsOnly,

                                LengthLimitingTextInputFormatter(6),

                              ],

                              style: const TextStyle(

                                fontSize: 18,

                                color: Colors.white,

                                letterSpacing: 8,

                              ),

                              decoration: const InputDecoration(

                                hintText: '请输入验证码',

                                hintStyle: TextStyle(

                                  color: Color(0xFF666666),

                                  fontSize: 16,

                                  letterSpacing: 0,

                                ),

                                border: InputBorder.none,

                                contentPadding:

                                    EdgeInsets.symmetric(vertical: 16),

                              ),

                            ),

                          ),

                          // 分隔?
                          Container(

                            height: 24,

                            width: 1,

                            color: const Color(0xFF333333),

                          ),

                          // 获取验证码按?
                          GestureDetector(

                            onTap: _isCountingDown ? null : _sendCode,

                            child: Container(

                              padding:

                                  const EdgeInsets.symmetric(horizontal: 16),

                              alignment: Alignment.center,

                              child: Text(

                                _isCountingDown ? '${_countdown}s' : '获取验证码',

                                style: TextStyle(

                                  fontSize: 14,

                                  color: _isCountingDown

                                      ? const Color(0xFF666666)

                                      : (_isPhoneValid

                                          ? const Color(0xFF1E88E5)

                                          : const Color(0xFF666666)),

                                ),

                              ),

                            ),

                          ),

                        ],

                      ),

                    ),

                    const SizedBox(height: 40),



                    // 登录按钮

                    ElevatedButton(

                      onPressed: (_isPhoneValid && _isCodeValid) && !_isLoading

                          ? _login

                          : null,

                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xFF1E88E5),

                        disabledBackgroundColor:

                            const Color(0xFF1E88E5).withValues(alpha: 0.3),

                        foregroundColor: Colors.white,

                        disabledForegroundColor:

                            Colors.white.withValues(alpha: 0.5),

                        padding: const EdgeInsets.symmetric(vertical: 16),

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(12),

                        ),

                        elevation: 0,

                      ),

                      child: _isLoading

                          ? const SizedBox(

                              width: 20,

                              height: 20,

                              child: CircularProgressIndicator(

                                strokeWidth: 2,

                                color: Colors.white,

                              ),

                            )

                          : const Text(
                              '登 录',
                              style: TextStyle(

                                fontSize: 18,

                                letterSpacing: 8,

                              ),

                            ),

                    ),

                    const SizedBox(height: 24),



                    // 协议勾?
                    Row(

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [

                        SizedBox(

                          width: 24,

                          height: 24,

                          child: Checkbox(

                            value: true,

                            onChanged: (value) {},

                            activeColor: const Color(0xFF1E88E5),

                            side: const BorderSide(

                              color: Color(0xFF666666),

                              width: 1.5,

                            ),

                            shape: RoundedRectangleBorder(

                              borderRadius: BorderRadius.circular(4),

                            ),

                          ),

                        ),

                        const SizedBox(width: 8),

                        const Text(

                          '我已阅读并同意',

                          style: TextStyle(

                            color: Color(0xFF9E9E9E),

                            fontSize: 13,

                          ),

                        ),

                        GestureDetector(

                          onTap: () {},

                          child: const Text(

                            '《用户协议》',

                            style: TextStyle(

                              color: Color(0xFF1E88E5),

                              fontSize: 13,

                            ),

                          ),

                        ),

                        const Text(
                          '和',
                          style: TextStyle(

                            color: Color(0xFF9E9E9E),

                            fontSize: 13,

                          ),

                        ),

                        GestureDetector(

                          onTap: () {},

                          child: const Text(

                            '《隐私政策》',

                            style: TextStyle(

                              color: Color(0xFF1E88E5),

                              fontSize: 13,

                            ),

                          ),

                        ),

                      ],

                    ),

                  ],

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



// 呼吸星空效果（参?demo StarEffect?
class BreathingStars extends StatefulWidget {

  final double height;

  const BreathingStars({super.key, this.height = 160});



  @override

  State<BreathingStars> createState() => _BreathingStarsState();

}



class _BreathingStarsState extends State<BreathingStars>

    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  final _random = Random();

  late List<_StarData> _stars;



  @override
  void initState() {
    super.initState();
    final rand = Random(42); // 固定种子，保证每次启动星场一致
    _stars = List.generate(
        12,
        (_) => _StarData(
              x: rand.nextDouble(),
              y: rand.nextDouble(),
              size: 0.5 + rand.nextDouble() * 2.0,
              brightness: 0.3 + rand.nextDouble() * 0.7,
              phase: rand.nextDouble() * pi * 2,
              lastTwinkle: 0,
              roundsLeft: 2 + rand.nextInt(3), // 随机2-4轮
            ));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )
      ..addListener(_onAnimationTick)
      ..repeat(reverse: true);
  }

  void _onAnimationTick() {
    final v = _controller.value;
    for (final star in _stars) {
      final twinkle = sin(v * pi + star.phase);
      // 单颗星星呼吸一轮结束（从最低点回升时）
      if (star.lastTwinkle < -0.5 && twinkle > -0.5) {
        star.roundsLeft--;
        if (star.roundsLeft <= 0) {
          star.x = _random.nextDouble();
          star.y = _random.nextDouble();
          star.roundsLeft = 2 + _random.nextInt(3); // 重置为2-4轮
        }
      }
      star.lastTwinkle = twinkle;
    }
  }



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return SizedBox(

      height: widget.height,

      width: double.infinity,

      child: AnimatedBuilder(

        animation: _controller,

        builder: (context, _) {

          return CustomPaint(

            painter: _StarPainter(

              stars: _stars,

              twinkle: _controller.value,

            ),

          );

        },

      ),

    );

  }

}



class _StarData {

  double x, y, size, brightness, phase, lastTwinkle;

  int roundsLeft; // 剩余呼吸轮次，到0时换位

  _StarData({

    required this.x,

    required this.y,

    required this.size,

    required this.brightness,

    required this.phase,

    required this.lastTwinkle,

    required this.roundsLeft,

  });

}



class _StarPainter extends CustomPainter {

  final List<_StarData> stars;

  final double twinkle;



  _StarPainter({

    required this.stars,

    required this.twinkle,

  });



  @override

  void paint(Canvas canvas, Size size) {

    if (size.width <= 0 || size.height <= 0) return;



    for (final star in stars) {

      // alpha = (0.2 + 0.8 * (sin(twinkle*2π + phase) + 1) / 2) * brightness

      // 透明度下?.2，保证星点不会完全消?
      final alpha =
          ((0.2 + 0.8 * (sin(twinkle * pi + star.phase) + 1) / 2) *

                  star.brightness)

              .clamp(0.0, 1.0);



      final dx = star.x * size.width;

      final dy = star.y * size.height;



      // 柔和光晕

      final glowPaint = Paint()

        ..color = Color.fromRGBO(180, 210, 255, alpha * 0.15)

        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(dx, dy), star.size * 3, glowPaint);



      // 星点（白色，动态透明度）

      final paint = Paint()..color = Color.fromRGBO(255, 255, 255, alpha);

      canvas.drawCircle(Offset(dx, dy), star.size, paint);

    }

  }



  @override

  bool shouldRepaint(covariant _StarPainter oldDelegate) =>

      oldDelegate.twinkle != twinkle;

}



// ==================== 全屏地图详情?====================



class MapDetailPage extends StatefulWidget {

  final double lng;

  final double lat;

  final String road;

  final String addr;



  const MapDetailPage({

    super.key,

    required this.lng,

    required this.lat,

    required this.road,

    required this.addr,

  });



  @override

  State<MapDetailPage> createState() => _MapDetailPageState();

}



class _MapDetailPageState extends State<MapDetailPage> {

  final _api = ApiService();

  late WebViewController _mapCtrl;

  double _lng = 0;

  double _lat = 0;

  String _road = '';

  String _addr = '';

  bool _locating = false;

  final Set<String> _loadingCmds = {};



  @override

  void initState() {

    super.initState();

    _lng = widget.lng;

    _lat = widget.lat;

    _road = widget.road;

    _addr = widget.addr;

    _initMap();

  }



  void _initMap() {

    final html = '''

<!DOCTYPE html>

<html>

<head>

<meta charset="utf-8">

<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">

<style>html,body,#map{margin:0;padding:0;width:100%;height:100%}.amap-logo,.amap-copyright{display:none!important}</style>

</head>

<body>

<div id="map"></div>

<script src="https://webapi.amap.com/maps?v=2.0&key=d994dd4df0ea0c29d42fd092591853ef"></script>

<script>

var map = new AMap.Map('map',{

  zoom:18,

  center:[$_lng,$_lat],

  mapStyle:'amap://styles/dark'

});

var marker = new AMap.Marker({

  position:[$_lng,$_lat],

  content:'<div style="width:16px;height:24px;"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 24"><path d="M8 0C3.6 0 0 3.6 0 8c0 6 8 16 8 16s8-10 8-16C16 3.6 12.4 0 8 0z" fill="#2196F3"/><circle cx="8" cy="8" r="3.5" fill="#fff"/></svg></div>',

  offset:new AMap.Pixel(-8,-24)

});

marker.setMap(map);

</script>

</body>

</html>''';



    _mapCtrl = WebViewController()

      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      ..setBackgroundColor(const Color(0xFF2B3136))

      ..loadHtmlString(html);

  }



  void _updateMapCenter() {

    _mapCtrl.runJavaScript('''

      if (typeof map !== 'undefined') {

        map.setCenter([$_lng,$_lat]);

        if (typeof marker !== 'undefined') marker.setPosition([$_lng,$_lat]);

      }

    ''');

  }



  Future<void> _relocate() async {

    setState(() => _locating = true);

    try {

      final locResp = await _api.getCarLocation();

      if (locResp.code == 0 && locResp.data != null) {

        final locData = locResp.data as Map;

        final newLng = (locData['lng'] as num?)?.toDouble() ?? 0;

        final newLat = (locData['lat'] as num?)?.toDouble() ?? 0;

        if (newLng != 0 && newLat != 0) {

          // 高德逆地理编码获取地址

          String newRoad = locData['roadName']?.toString() ?? '';

          String newAddr = locData['addrDesc']?.toString() ?? '';

          try {

            const key = 'd994dd4df0ea0c29d42fd092591853ef';

            final geoUrl =

                'https://restapi.amap.com/v3/geocode/regeo?location=$newLng,$newLat&key=$key&extensions=base';

            final geoResp = await Dio().get(geoUrl);

            if (geoResp.statusCode == 200 && geoResp.data['status'] == '1') {

              final regeo = geoResp.data['regeocode'];

              newRoad = regeo['roadway']?['name']?.toString() ?? newRoad;

              newAddr = regeo['formatted_address']?.toString() ?? newAddr;

            }

          } catch (_) {}

          setState(() {

            _lng = newLng;

            _lat = newLat;

            _road = newRoad;

            _addr = newAddr;

          });

          _updateMapCenter();

          if (mounted) {

            ScaffoldMessenger.of(context).showSnackBar(

              const SnackBar(

                  content: Text('定位成功'),

                  backgroundColor: Colors.green,

                  duration: Duration(seconds: 1)),

            );

          }

        }

      } else {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

                content: Text('定位失败: ${locResp.msg}'),

                backgroundColor: Colors.red),

          );

        }

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('定位失败: $e'), backgroundColor: Colors.red),

        );

      }

    }

    setState(() => _locating = false);

  }

  Future<void> _sendCommand(String cmd) async {

    setState(() => _loadingCmds.add(cmd));

    final resp = await _api.executeCommand(cmd);

    if (!mounted) return;

    setState(() => _loadingCmds.remove(cmd));

    final ok = resp.code == 0;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(ok ? '指令已发送' : '发送失败 ${resp.msg}'),

        backgroundColor: ok ? Colors.green : Colors.red,

        duration: const Duration(seconds: 2),

      ),

    );

  }



  void _showNavigation() {

    showModalBottomSheet(

      context: context,

      backgroundColor: const Color(0xFF2B3136),

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),

      ),

      builder: (_) => SafeArea(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Padding(

              padding: EdgeInsets.all(16),

              child: Text('选择导航地图',

                  style: TextStyle(

                      color: Colors.white,

                      fontSize: 16,)),

            ),

            ListTile(

              leading: const Icon(Icons.map, color: Colors.blue),

              title: const Text('高德地图', style: TextStyle(color: Colors.white)),

              onTap: () {

                Navigator.pop(context);

                _launchMap(

                    'amapuri://route/plan/?dlat=$_lat&dlon=$_lng&dname=${Uri.encodeComponent('车辆位置')}&dev=0&t=0');

              },

            ),

            ListTile(

              leading: const Icon(Icons.map, color: Colors.green),

              title: const Text('百度地图', style: TextStyle(color: Colors.white)),

              onTap: () {

                Navigator.pop(context);

                _launchMap(

                    'baidumap://map/direction?destination=$_lat,$_lng&destination_name=${Uri.encodeComponent('车辆位置')}&coord_type=gcj02&mode=driving');

              },

            ),

            ListTile(

              leading: const Icon(Icons.map, color: Colors.orange),

              title: const Text('腾讯地图', style: TextStyle(color: Colors.white)),

              onTap: () {

                Navigator.pop(context);

                _launchMap(

                    'qqmap://map/routeplan?type=drive&to=${Uri.encodeComponent('车辆位置')}&tocoord=$_lat,$_lng');

              },

            ),

            const SizedBox(height: 8),

          ],

        ),

      ),

    );

  }



  Future<void> _launchMap(String url) async {

    try {

      final uri = Uri.parse(url);

      await launchUrl(uri, mode: LaunchMode.externalApplication);

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('未安装对应地图应用'), backgroundColor: Colors.red),

      );

    }

  }



  @override

  Widget build(BuildContext context) {

    final displayAddr =

        _addr.isNotEmpty ? _addr : (_road.isNotEmpty ? _road : '未知位置');



    return Scaffold(

      backgroundColor: const Color(0xFF1A1F24),

      body: Stack(

        children: [

          // 全屏地图

          WebViewWidget(controller: _mapCtrl),



          // 返回按钮

          Positioned(

            top: MediaQuery.of(context).padding.top + 8,

            left: 8,

            child: GestureDetector(

              onTap: () => Navigator.pop(context),

              child: Container(

                width: 40,

                height: 40,

                decoration: BoxDecoration(

                  color: Colors.black.withValues(alpha: 0.6),

                  shape: BoxShape.circle,

                ),

                child:

                    const Icon(Icons.arrow_back, color: Colors.white, size: 22),

              ),

            ),

          ),



          // 左下?个功能按?
          Positioned(

            left: 12,

            bottom: 110,

            child: Column(

              children: [

                _buildMapBtn(Icons.my_location, '定位', _relocate,

                    loading: _locating),

                const SizedBox(height: 12),

                _buildMapBtn(Icons.lightbulb_outline, '闪灯',

                    () => _sendCommand('FlashLight'),

                    loading: _loadingCmds.contains('FlashLight')),

                const SizedBox(height: 12),

                _buildMapBtn(Icons.volume_up_outlined, '鸣笛',

                    () => _sendCommand('Whistle'),

                    loading: _loadingCmds.contains('Whistle')),

                const SizedBox(height: 12),

                _buildMapBtn(Icons.flash_on_outlined, '闪灯鸣笛',

                    () => _sendCommand('RemoteSearchCar'),

                    loading: _loadingCmds.contains('RemoteSearchCar')),

              ],

            ),

          ),



          // 底部地址?+ 导航按钮

          Positioned(

            left: 0,

            right: 0,

            bottom: 0,

            child: Container(

              padding: EdgeInsets.fromLTRB(

                  20, 16, 20, MediaQuery.of(context).padding.bottom + 16),

              decoration: BoxDecoration(

                color: const Color(0xFF2B3136),

                borderRadius:

                    const BorderRadius.vertical(top: Radius.circular(16)),

                boxShadow: [

                  BoxShadow(

                      color: Colors.black.withValues(alpha: 0.3),

                      blurRadius: 10)

                ],

              ),

              child: Row(

                children: [

                  Expanded(

                    child: Text(

                      displayAddr,

                      style: const TextStyle(color: Colors.white, fontSize: 14),

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                    ),

                  ),

                  const SizedBox(width: 12),

                  GestureDetector(

                    onTap: _showNavigation,

                    child: Container(

                      padding: const EdgeInsets.symmetric(

                          horizontal: 16, vertical: 10),

                      decoration: BoxDecoration(

                        color: const Color(0xFF007AFF),

                        borderRadius: BorderRadius.circular(20),

                      ),

                      child: const Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Icon(Icons.navigation, color: Colors.white, size: 18),

                          SizedBox(width: 6),

                          Text('导航',

                              style:

                                  TextStyle(color: Colors.white, fontSize: 14)),

                        ],

                      ),

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



  Widget _buildMapBtn(IconData icon, String label, VoidCallback onTap,

      {bool loading = false}) {

    return GestureDetector(

      onTap: loading ? null : onTap,

      child: Container(

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        decoration: BoxDecoration(

          color: Colors.black.withValues(alpha: 0.6),

          borderRadius: BorderRadius.circular(20),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            if (loading)

              const SizedBox(

                width: 16,

                height: 16,

                child: CircularProgressIndicator(

                    strokeWidth: 2, color: Colors.white),

              )

            else

              Icon(icon, color: Colors.white, size: 16),

            const SizedBox(width: 6),

            Text(label,

                style: const TextStyle(color: Colors.white, fontSize: 13)),

          ],

        ),

      ),

    );

  }

}



// 首页

class HomePage extends StatefulWidget {

  const HomePage({super.key});



  @override

  State<HomePage> createState() => _HomePageState();

}



class _HomePageState extends State<HomePage>

    with TickerProviderStateMixin, WidgetsBindingObserver {

  final ApiService _api = ApiService();

  Future<ApiResponse> _executeWithPinCheck(String cmd,
      {Map<String, dynamic>? extraParams}) async {
    var resp = await _api.executeCommand(cmd, extraParams: extraParams);
    if (resp.code == 3) {
      _pollingPaused = true;
      try {
        // 尝试使用预设控车码
        final prefs = await SharedPreferences.getInstance();
        final presetEnabled = prefs.getBool('preset_pin_enabled') ?? false;
        final presetPin = prefs.getString('preset_pin_value') ?? '';
        if (presetEnabled && presetPin.length == 6) {
          resp = await _api.executeCommand(cmd, extraParams: extraParams, pin: presetPin);
          if (resp.code == 0) {
            return resp;
          }
          // 预设码错误，继续弹出手动输入
        }
        final pin = await _showPinInputDialog();
        if (pin == null || pin.isEmpty) {
          return ApiResponse(code: -1, msg: '已取消');
        }
        resp = await _api.executeCommand(cmd, extraParams: extraParams, pin: pin);
        return resp;
      } finally {
        _pollingPaused = false;
      }
    }
    return resp;
  }

  Future<String?> _showPinInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E2429),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('输入控车码',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A3038),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '6位数字',
                  hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('确认', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  String _carName = '未知车辆';

  String _plateNumber = '';

  String _vin = '';

  String _seriesName = '';

  String _userNickname = '';

  int _range = 0; // 续航里程

  int _totalOdometer = 0; // 总里?
  double _fuelPercent = 0; // 油量百分?
  int _companionDays = 0; // 陪伴天数

  bool _showTotal = false; // 是否显示总里?
  bool _isLoading = true;

  bool _touching3D = false;

  int _vehicleTemp = 0; // 车内温度

  int _envTemp = 0; // 车外温度

  bool _acOn = false; // 空调状?
  String _acStatusText = '车内空调已关闭'; // 空调状态文?
  // 空调详情页轮询更新回?
  void Function(Map<String, dynamic>)? _acPageUpdateCallback;

  String _insuranceCompany = '未知';

  String _insurancePhone = '未知';

  double _locationLng = 0;

  double _locationLat = 0;

  String _locationAddr = '';

  String _locationRoad = '';



  // 地图 WebView 缓存

  WebViewController? _mapController;

  Widget? _mapWidget;



  // 3D模型缓存

  final GlobalKey<Car3DViewerState> _car3DKey = GlobalKey<Car3DViewerState>();

  Car3DViewer? _car3DViewer;



  Car3DViewer _getCar3DViewer() {

    _car3DViewer ??= Car3DViewer(

      key: _car3DKey,

      onToggleView: (isTopView) {

        if (isTopView) {

          // 隐藏首页组件

          _headerHideController.forward();

          _bottomHideController.forward();

          // 800ms后导航到详情页（与相机动画同步）

          Future.delayed(const Duration(milliseconds: 800), () {

            if (_carData != null && mounted) {

              Navigator.of(context)

                  .push(

                PageRouteBuilder(

                  opaque: false,

                  barrierDismissible: false,

                  barrierColor: Colors.transparent,

                  pageBuilder: (_, __, ___) =>

                      VehicleDetailPage(data: _carData!),

                  transitionDuration: Duration.zero,

                  reverseTransitionDuration: Duration.zero,

                ),

              )

                  .then((_) {

                // 返回时重置为普通视角并恢复首页组件

                _car3DKey.currentState?.toggleTopView();

                _headerHideController.reverse();

                _bottomHideController.reverse();

              });

            }

          });

        }

      },

    );

    return _car3DViewer!;

  }



  // 控制按钮状?
  bool _lockActive = false;

  bool _ignitionActive = false;

  bool _windowActive = false;

  bool _sunroofActive = false;

  bool _commandSending = false; // 防止重复点击



  // 3D模型旋转时，首页组件隐藏/显示动画

  late AnimationController _headerHideController;

  late AnimationController _bottomHideController;

  late Animation<Offset> _headerSlideUp;

  late Animation<Offset> _bottomSlideDown;



  // 防抖：预期状态和不匹配计?
  final Map<String, dynamic> _expectedStates = {};

  final Map<String, int> _stateMismatchCount = {};



  // 缓存车辆数据

  Map<String, dynamic>? _carData;



  // 定时刷新

  Timer? _refreshTimer;

  bool _pollingPaused = false;

  bool _isBackground = false;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);



    _headerHideController = AnimationController(

      duration: const Duration(milliseconds: 800),

      vsync: this,

    );

    _bottomHideController = AnimationController(

      duration: const Duration(milliseconds: 800),

      vsync: this,

    );

    _headerSlideUp = Tween<Offset>(

      begin: Offset.zero,

      end: const Offset(0, -1),

    ).animate(CurvedAnimation(

      parent: _headerHideController,

      curve: Curves.easeOutCubic,

    ));

    _bottomSlideDown = Tween<Offset>(

      begin: Offset.zero,

      end: const Offset(0, 1),

    ).animate(CurvedAnimation(

      parent: _bottomHideController,

      curve: Curves.easeOutCubic,

    ));



    _loadData();

    _startPolling();

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();

    _headerHideController.dispose();

    _bottomHideController.dispose();

    super.dispose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.paused ||

        state == AppLifecycleState.inactive) {

      // 进入后台，停止轮?
      _isBackground = true;

      _refreshTimer?.cancel();

      _refreshTimer = null;

    } else if (state == AppLifecycleState.resumed) {

      // 回到前台，恢复轮询并立即刷新

      _isBackground = false;

      _refreshCarData();

      _startPolling();

    }

  }



  void _startPolling() {

    _refreshTimer?.cancel();

    if (_isBackground) return;

    _refreshTimer =

        Timer.periodic(const Duration(seconds: 5), (_) => _refreshCarData());

  }



  Future<void> _loadData() async {

    // 先获取车辆信息，确保carId已设?
    final carsResp = await _api.getUserCars();

    if (carsResp.code == 0 && carsResp.data != null) {

      final cars = carsResp.data;

      if (cars is List && cars.isNotEmpty) {

        final car = cars[0];

        setState(() {

          _carName = car['carName'] ?? '未知车辆';

          _seriesName = car['seriesName'] ?? '';

          _plateNumber = car['plateNumber'] ?? '';

          _vin = car['vin'] ?? '';

          _userNickname = car['userNickname'] ?? '';

          _insuranceCompany = car['insuranceCompany'] ?? '未知';

          _insurancePhone = car['insurancePhone'] ?? '未知';

        });

        if (car['carId'] != null) {

          final carId = car['carId'].toString();

          _api.setCarId(carId);

          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('carId', carId);

        }

      }

    }



    // carId已设置后，并行获取其他数?
    final results = await Future.wait([

      _api.getCarData(),

      _api.getRealNameRecord(),

      _api.getCarLocation(),

    ]);



    final carDataResp = results[0];

    final realNameResp = results[1];

    final locationResp = results[2];



    if (carDataResp.code == 0 && carDataResp.data != null) {

      final d = carDataResp.data;

      _carData = d;

      setState(() {

        _range = (d['remainedOilMile'] ?? 0).round();

        _totalOdometer = (d['totalOdometer'] ?? 0).round();

        _fuelPercent = (d['remainingFuel'] ?? 0).toDouble();

        _vehicleTemp = (d['vehicleTemperature'] ?? 0).round();

        _envTemp = (d['environmentalTemp'] ?? 0).round();

        _acOn = d['airStatus'] == 1;

        _acStatusText = _acOn ? '车内空调已开启' : '车内空调已关闭';

      });

      _syncControlButtons();

    }



    if (realNameResp.code == 0 && realNameResp.data != null) {

      final list = realNameResp.data['list'];

      if (list != null && list.isNotEmpty) {

        final authDate = DateTime.tryParse(list[0]['createAt'] ?? '');

        if (authDate != null) {

          setState(() {

            _companionDays = DateTime.now().difference(authDate).inDays;

          });

        }

      }

    }



    if (locationResp.code == 0 &&

        locationResp.data != null &&

        locationResp.data is Map) {

      final loc = locationResp.data;

      final lng = (loc['lng'] ?? 0).toDouble();

      final lat = (loc['lat'] ?? 0).toDouble();

      setState(() {

        _locationLng = lng;

        _locationLat = lat;

        _locationAddr = loc['addrDesc'] ?? '';

        _locationRoad = loc['roadName'] ?? '';

      });

      // 高德逆地理编码获取路?
      _reverseGeocode(lng, lat);

    }



    setState(() {

      _isLoading = false;

    });

  }



  // 刷新车辆数据（定时调用，参?demo 轮询逻辑?
  Future<void> _refreshCarData() async {
    if (_pollingPaused) return;

    await _api.refreshToken();

    final carsResp =

        await _api.getUserCars().catchError((_) => ApiResponse(code: -1));

    if (carsResp.code == 0 && carsResp.data != null) {

      final cars = carsResp.data;

      if (cars is List && cars.isNotEmpty) {

        final car = cars[0];

        setState(() {

          _seriesName = car['seriesName'] ?? _seriesName;

          _plateNumber = car['plateNumber'] ?? _plateNumber;

          _vin = car['vin'] ?? _vin;

          _userNickname = car['userNickname'] ?? _userNickname;

          _insuranceCompany = car['insuranceCompany'] ?? _insuranceCompany;

          _insurancePhone = car['insurancePhone'] ?? _insurancePhone;

        });

        // 确保carId已设?
        if (car['carId'] != null && _api.carId == null) {

          final carId = car['carId'].toString();

          _api.setCarId(carId);

          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('carId', carId);

        }

      }

    }

    final resp = await _api.getCarData();

    if (resp.code == 0 && resp.data != null) {

      final d = resp.data;

      _carData = d;

      setState(() {

        _range = (d['remainedOilMile'] ?? 0).round();

        _totalOdometer = (d['totalOdometer'] ?? 0).round();

        _fuelPercent = (d['remainingFuel'] ?? 0).toDouble();

        _vehicleTemp = (d['vehicleTemperature'] ?? 0).round();

        _envTemp = (d['environmentalTemp'] ?? 0).round();

        _acOn = d['airStatus'] == 1;

        _acStatusText = _acOn ? '车内空调已开启' : '车内空调已关闭';

      });

      _syncControlButtons();

      // 推送数据到空调详情?
      _acPageUpdateCallback?.call(d);

      // 同步3D模型车门/车窗/天窗/尾箱动画

      _car3DKey.currentState?.updateBodyStatus(d);

    }

  }



  // 同步控制按钮状态（带防抖，参?demo?
  void _syncControlButtons() {

    if (_carData == null) return;

    final d = _carData!;



    // 锁车状态：任意车门解锁 = unlocked

    final locks = [

      d['driverDoorLock'],

      d['passengerDoorLock'],

      d['leftRearDoorLock'],

      d['rightRearDoorLock']

    ];

    final isUnlocked = locks.any((v) => v == 1);

    _syncState('lock', isUnlocked, (v) => setState(() => _lockActive = v));



    // 点火状?
    final isEngineOn = d['engineStatus'] == 1 || d['engineStatus'] == 2;

    _syncState(

        'ignition', isEngineOn, (v) => setState(() => _ignitionActive = v));



    // 车窗状?
    final windows = [

      d['diverWindow'],

      d['passengerWindow'],

      d['leftRearWindow'],

      d['rightRearWindow']

    ];

    final isWindowOpen = windows.any((v) => v == 1);

    _syncState(

        'window', isWindowOpen, (v) => setState(() => _windowActive = v));



    // 天窗状?
    final isSunroofOpen = d['sunroof'] == 1;

    _syncState(

        'sunroof', isSunroofOpen, (v) => setState(() => _sunroofActive = v));

  }



  void _syncState(String key, bool actualValue, Function(bool) setter) {

    if (_expectedStates[key] != null) {

      if (actualValue != _expectedStates[key]) {

        _stateMismatchCount[key] = (_stateMismatchCount[key] ?? 0) + 1;

        if (_stateMismatchCount[key]! > 3) {

          _expectedStates.remove(key);

          _stateMismatchCount.remove(key);

          setter(actualValue);

        }

      } else {

        _expectedStates.remove(key);

        _stateMismatchCount.remove(key);

        setter(actualValue);

      }

    } else {

      setter(actualValue);

    }

  }



  void _showNotification(String msg) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopNotification(
        message: msg,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }



  // 锁车/解锁

  Future<void> _executeLock() async {

    if (_commandSending) return;

    _commandSending = true;

    _showNotification('指令发送中...');

    final isActive = _lockActive;

    final cmd = isActive ? 'LockDoor' : 'UnLockDoor';



    final resp = await _executeWithPinCheck(cmd);

    if (resp.code == 0) {

      setState(() => _lockActive = !_lockActive);

      _expectedStates['lock'] = _lockActive;

      _stateMismatchCount['lock'] = 0;

      _showNotification(isActive ? '闭锁成功' : '解锁成功');

      _refreshCarData();

    } else {

      _showNotification('操作失败: ${resp.msg}');

    }

    _commandSending = false;

  }



  // 点火/熄火

  Future<void> _executeIgnition() async {

    if (_commandSending) return;

    _commandSending = true;

    _showNotification('指令发送中...');

    final isOn = _ignitionActive;

    final cmd = isOn ? 'CloseEngine' : 'OpenEngine';



    final resp = await _executeWithPinCheck(cmd);

    if (resp.code == 0) {

      setState(() => _ignitionActive = !_ignitionActive);

      _expectedStates['ignition'] = _ignitionActive;

      _stateMismatchCount['ignition'] = 0;

      _showNotification(isOn ? '熄火成功' : '点火成功');

      _refreshCarData();

    } else {

      _showNotification('操作失败: ${resp.msg}');

    }

    _commandSending = false;

  }



  // 车窗控制

  Future<void> _executeWindow() async {

    if (_commandSending) return;

    if (!_windowActive) {

      _showWindowControl();

      return;

    }

    _commandSending = true;

    final resp = await _executeWithPinCheck('CloseWindow');

    if (resp.code == 0) {

      setState(() => _windowActive = false);

      _expectedStates['window'] = false;

      _stateMismatchCount['window'] = 0;

      _showNotification('关窗成功');

      _refreshCarData();

    } else {

      _showNotification('操作失败: ${resp.msg}');

    }

    _commandSending = false;

  }



  void _showWindowControl() {

    showDialog(

      context: context,

      builder: (ctx) => Dialog(

        backgroundColor: const Color(0xFF1E2429),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('车窗控制',

                  style: TextStyle(

                      color: Colors.white,

                      fontSize: 18,)),

              const SizedBox(height: 24),

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [

                  _buildModalOption(

                      ctx, '开启车窗', 'assets/images/icons/quankai-web.png',

                      () async {

                    Navigator.pop(ctx);

                    if (_commandSending) return;

                    _commandSending = true;

                    _showNotification('指令发送中...');

                    final resp = await _executeWithPinCheck('OpenWindow');

                    if (resp.code == 0) {

                      setState(() => _windowActive = true);

                      _expectedStates['window'] = true;

                      _stateMismatchCount['window'] = 0;

                      _showNotification('开窗成功');;

                      _refreshCarData();

                    } else {

                      _showNotification('操作失败: ${resp.msg}');

                    }

                    _commandSending = false;

                  }),

                  _buildModalOption(

                      ctx, '车窗微开', 'assets/images/icons/quankai-web.png',

                      () async {

                    Navigator.pop(ctx);

                    if (_commandSending) return;

                    _commandSending = true;

                    _showNotification('指令发送中...');

                    final resp = await _executeWithPinCheck('WindowSlit');

                    if (resp.code == 0) {

                      setState(() => _windowActive = true);

                      _expectedStates['window'] = true;

                      _stateMismatchCount['window'] = 0;

                      _showNotification('车窗通风成功');

                      _refreshCarData();

                    } else {

                      _showNotification('操作失败: ${resp.msg}');

                    }

                    _commandSending = false;

                  }),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }



  // 天窗控制

  Future<void> _executeSunroof() async {

    if (_commandSending) return;

    if (!_sunroofActive) {

      _showSunroofControl();

      return;

    }

    _commandSending = true;

    _showNotification('指令发送中...');

    final resp = await _executeWithPinCheck('CloseDormer');

    if (resp.code == 0) {

      setState(() => _sunroofActive = false);

      _expectedStates['sunroof'] = false;

      _stateMismatchCount['sunroof'] = 0;

      _showNotification('关天窗成功');;

      _refreshCarData();

    } else {

      _showNotification('操作失败: ${resp.msg}');

    }

    _commandSending = false;

  }



  void _showSunroofControl() {

    showDialog(

      context: context,

      builder: (ctx) => Dialog(

        backgroundColor: const Color(0xFF1E2429),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('天窗控制',

                  style: TextStyle(

                      color: Colors.white,

                      fontSize: 18,)),

              const SizedBox(height: 24),

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [

                  _buildModalOption(ctx, '天窗全开',

                      'assets/images/icons/tianchuangkaiqi-web.png', () async {

                    Navigator.pop(ctx);

                    if (_commandSending) return;

                    _commandSending = true;

                    _showNotification('指令发送中...');

                    final resp = await _executeWithPinCheck('SkyWindowLiftUp');

                    if (resp.code == 0) {

                      setState(() => _sunroofActive = true);

                      _expectedStates['sunroof'] = true;

                      _stateMismatchCount['sunroof'] = 0;

                      _showNotification('天窗全开成功');

                      _refreshCarData();

                    } else {

                      _showNotification('操作失败: ${resp.msg}');

                    }

                    _commandSending = false;

                  }),

                  _buildModalOption(ctx, '天窗翘起',

                      'assets/images/icons/tianchuangqiaoqi-web.png', () async {

                    Navigator.pop(ctx);

                    if (_commandSending) return;

                    _commandSending = true;

                    _showNotification('指令发送中...');

                    final resp = await _executeWithPinCheck('SkyWindowLiftUp');

                    if (resp.code == 0) {

                      setState(() => _sunroofActive = true);

                      _expectedStates['sunroof'] = true;

                      _stateMismatchCount['sunroof'] = 0;

                      _showNotification('天窗翘起成功');

                      _refreshCarData();

                    } else {

                      _showNotification('操作失败: ${resp.msg}');

                    }

                    _commandSending = false;

                  }),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildModalOption(

      BuildContext ctx, String label, String icon, VoidCallback onTap) {

    return GestureDetector(

      onTap: onTap,

      child: Column(

        children: [

          Container(

            width: 72,

            height: 72,

            decoration: const BoxDecoration(

              color: Color(0xFF2B3136),

              shape: BoxShape.circle,

            ),

            child: Center(child: Image.asset(icon, width: 32, height: 32)),

          ),

          const SizedBox(height: 8),

          Text(label,

              style: const TextStyle(color: Colors.white, fontSize: 12)),

        ],

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    return Scaffold(

      backgroundColor: Colors.transparent,

      body: Stack(

        children: [

          // 背景图（放大1.3倍，顶边对齐?
          Positioned(

            top: 0,

            child: Image.asset(

              'assets/images/BG.webp',

              width: size.width * 1.3,

              height: size.height * 1.3,

              fit: BoxFit.fill,

              alignment: Alignment.topCenter,

            ),

          ),

          // 半透明遮罩（较轻，让背景图更亮?
          Container(

            width: size.width,

            height: size.height,

            color: Colors.black.withValues(alpha: 0.3),

          ),

          // 呼吸星空效果

          Positioned(

            top: 0,

            left: 0,

            right: 0,

            child: BreathingStars(height: size.height * 0.18),

          ),

          // 内容

          SafeArea(

            child: _isLoading

                ? const Center(

                    child: CircularProgressIndicator(color: Color(0xFF1E88E5)),

                  )

                : SingleChildScrollView(

                    physics: _touching3D

                        ? const NeverScrollableScrollPhysics()

                        : const AlwaysScrollableScrollPhysics(),

                    child: Padding(

                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          // 顶部信息?
                          SlideTransition(

                            position: _headerSlideUp,

                            child: Row(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                // 左侧：车辆名?+ 陪伴天数

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment:

                                        CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        _carName,

                                        style: const TextStyle(

                                          color: Colors.white,

                                          fontSize: 22,

                                          fontWeight: FontWeight.w400,

                                        ),

                                        maxLines: 1,

                                        overflow: TextOverflow.ellipsis,

                                      ),

                                      const SizedBox(height: 8),

                                      Text(

                                        _companionDays > 0

                                            ? '已陪伴您 $_companionDays 天'

                                            : '',

                                        style: const TextStyle(

                                          color: Color(0xFF1E88E5),

                                          fontSize: 13,

                                        ),

                                      ),

                                    ],

                                  ),

                                ),

                                // 右侧：公里数 + 油量?
                                Column(

                                  crossAxisAlignment: CrossAxisAlignment.end,

                                  children: [

                                    GestureDetector(

                                      onTap: () {

                                        setState(() {

                                          _showTotal = !_showTotal;

                                        });

                                      },

                                      child: Text(

                                        _showTotal

                                            ? '$_totalOdometer km'

                                            : '$_range km',

                                        style: const TextStyle(

                                          color: Colors.white,

                                          fontSize: 22,

                                          fontWeight: FontWeight.w400,

                                        ),

                                      ),

                                    ),

                                    const SizedBox(height: 8),

                                    // 油量?
                                    SizedBox(

                                      width: 100,

                                      child: ClipRRect(

                                        borderRadius: BorderRadius.circular(3),

                                        child: LinearProgressIndicator(

                                          value: _fuelPercent / 100,

                                          minHeight: 6,

                                          backgroundColor:

                                              const Color(0xFF333333),

                                          valueColor:

                                              AlwaysStoppedAnimation<Color>(

                                            _fuelPercent > 20

                                                ? const Color(0xFF4CAF50)

                                                : const Color(0xFFFF5252),

                                          ),

                                        ),

                                      ),

                                    ),

                                  ],

                                ),

                              ],

                            ), // Row

                          ), // SlideTransition

                          // 3D 模型区域 - 正方形，边长=屏幕宽度

                          LayoutBuilder(

                            builder: (context, constraints) {

                              return Listener(

                                onPointerDown: (_) =>

                                    setState(() => _touching3D = true),

                                onPointerUp: (_) =>

                                    setState(() => _touching3D = false),

                                onPointerCancel: (_) =>

                                    setState(() => _touching3D = false),

                                child: Container(

                                  width: constraints.maxWidth,

                                  height: constraints.maxWidth,

                                  child: _getCar3DViewer(),

                                ),

                              );

                            },

                          ),

                          const SizedBox(height: 0),

                          // 模型下方组件（动画隐藏）

                          SlideTransition(

                            position: _bottomSlideDown,

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                // 控制按钮区域

                                Row(

                                  mainAxisAlignment:

                                      MainAxisAlignment.spaceBetween,

                                  children: [

                                    _buildControlButton(

                                      activeIcon:

                                          'assets/images/icons/suoding-web.png',

                                      inactiveIcon:

                                          'assets/images/icons/kaisuo-web.png',

                                      label: '锁车',

                                      isActive: _lockActive,

                                      onTap: _executeLock,

                                    ),

                                    _buildControlButton(

                                      activeIcon:

                                          'assets/images/icons/xihuo-web.png',

                                      inactiveIcon:

                                          'assets/images/icons/dianhuo-web.png',

                                      label: '点火',

                                      isActive: _ignitionActive,

                                      onTap: _executeIgnition,

                                    ),

                                    _buildControlButton(

                                      activeIcon:

                                          'assets/images/icons/chechuangguanbi-web.png',

                                      inactiveIcon:

                                          'assets/images/icons/quankai-web.png',

                                      label: '车窗',

                                      isActive: _windowActive,

                                      onTap: _executeWindow,

                                    ),

                                    _buildControlButton(

                                      activeIcon:

                                          'assets/images/icons/tianchuangguanbi-web.png',

                                      inactiveIcon:

                                          'assets/images/icons/tianchuangkaiqi-web.png',

                                      label: '天窗',

                                      isActive: _sunroofActive,

                                      onTap: _executeSunroof,

                                    ),

                                  ],

                                ),

                                const SizedBox(height: 16),

                                // 信息卡片：定?+ 空调

                                Row(

                                  children: [

                                    // 定位地图卡片

                                    Expanded(

                                      child: GestureDetector(

                                        onTap: () {

                                          if (_locationLng != 0 &&

                                              _locationLat != 0) {

                                            Navigator.push(

                                              context,

                                              MaterialPageRoute(

                                                builder: (_) => MapDetailPage(

                                                  lng: _locationLng,

                                                  lat: _locationLat,

                                                  road: _locationRoad,

                                                  addr: _locationAddr,

                                                ),

                                              ),

                                            );

                                          }

                                        },

                                        child: Container(

                                          height: 140,

                                          decoration: BoxDecoration(

                                            color: const Color(0xFF2B3136),

                                            borderRadius:

                                                BorderRadius.circular(12),

                                          ),

                                          clipBehavior: Clip.antiAlias,

                                          child: Stack(

                                            children: [

                                              if (_locationLng != 0 &&

                                                  _locationLat != 0)

                                                _buildMapWebView()

                                              else

                                                const Center(

                                                  child: Icon(

                                                    Icons.map,

                                                    size: 48,

                                                    color: Color(0xFF555555),

                                                  ),

                                                ),

                                              Positioned(

                                                bottom: 8,

                                                right: 8,

                                                child: Container(

                                                  padding: const EdgeInsets

                                                      .symmetric(

                                                      horizontal: 8,

                                                      vertical: 4),

                                                  decoration: BoxDecoration(

                                                    color: Colors.black

                                                        .withValues(alpha: 0.6),

                                                    borderRadius:

                                                        BorderRadius.circular(

                                                            4),

                                                  ),

                                                  child: Text(

                                                    _locationRoad.isNotEmpty

                                                        ? _locationRoad

                                                        : (_locationAddr

                                                                .isNotEmpty

                                                            ? _locationAddr

                                                            : '未知位置'),

                                                    style: const TextStyle(

                                                      fontSize: 11,

                                                      color: Colors.white,

                                                    ),

                                                  ),

                                                ),

                                              ),

                                            ],

                                          ),

                                        ),

                                      ),

                                    ),

                                    const SizedBox(width: 12),

                                    // 空调卡片

                                    Expanded(

                                      child: GestureDetector(

                                        onTap: () {

                                          Navigator.push(

                                            context,

                                            MaterialPageRoute(

                                              builder: (_) => ACControlPage(

                                                api: _api,

                                                vehicleTemp: _vehicleTemp,

                                                envTemp: _envTemp,

                                                isOn: _acOn,

                                                setTemp: _vehicleTemp,

                                                onRegisterUpdate: (callback) {

                                                  _acPageUpdateCallback =

                                                      callback;

                                                },

                                              ),

                                            ),

                                          ).then((_) {

                                            // 返回后清除回?
                                            _acPageUpdateCallback = null;

                                          });

                                        },

                                        child: Container(

                                          height: 140,

                                          padding: const EdgeInsets.all(16),

                                          decoration: BoxDecoration(

                                            color: const Color(0xFF2B3136),

                                            borderRadius:

                                                BorderRadius.circular(12),

                                          ),

                                          child: Column(

                                            crossAxisAlignment:

                                                CrossAxisAlignment.start,

                                            mainAxisAlignment:

                                                MainAxisAlignment.spaceBetween,

                                            children: [

                                              // 温度显示

                                              Row(

                                                crossAxisAlignment:

                                                    CrossAxisAlignment.start,

                                                children: [

                                                  Text(

                                                    '$_vehicleTemp',

                                                    style: const TextStyle(

                                                      fontSize: 36,

                                                                                                            color: Colors.white,

                                                      height: 1,

                                                    ),

                                                  ),

                                                  const Text(

                                                    '°',

                                                    style: TextStyle(

                                                      fontSize: 13,

                                                      color: Color(0xFF9E9E9E),

                                                    ),

                                                  ),

                                                ],

                                              ),

                                              const Text(

                                                '车内温度',

                                                style: TextStyle(

                                                  fontSize: 11,

                                                  color: Color(0xFF9E9E9E),

                                                ),

                                              ),

                                              Text(

                                                _acStatusText,

                                                style: TextStyle(

                                                  fontSize: 11,

                                                  color: _acOn

                                                      ? const Color(0xFF1E88E5)

                                                      : Colors.white70,

                                                ),

                                              ),

                                            ],

                                          ),

                                        ),

                                      ),

                                    ),

                                  ],

                                ),

                                const SizedBox(height: 16),

                                // 功能列表

                                Container(

                                  decoration: BoxDecoration(

                                    color: const Color(0xFF2B3136),

                                    borderRadius: BorderRadius.circular(12),

                                  ),

                                  child: Column(

                                    children: [

                                      _buildFeatureItem('车辆诊断'),

                                      _buildFeatureItem('我的行程'),

                                      _buildFeatureItem('全景照片'),

                                      _buildFeatureItem('操作记录'),

                                      _buildFeatureItem('我的保险'),

                                    ],

                                  ),

                                ),

                                const SizedBox(height: 16),

                                // 车辆信息区域

                                Padding(

                                  padding: const EdgeInsets.only(left: 0),

                                  child: Column(

                                    crossAxisAlignment:

                                        CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        _seriesName.isNotEmpty

                                            ? _seriesName

                                            : _carName,

                                        style: const TextStyle(

                                          fontSize: 20,

                                          color: Colors.white,

                                        ),

                                      ),

                                      const SizedBox(height: 12),

                                      Text(

                                        '公里数：${_totalOdometer > 0 ? "$_totalOdometer km" : "--"}',

                                        style: TextStyle(

                                          fontSize: 12,

                                          color: Colors.white

                                              .withValues(alpha: 0.7),

                                          height: 1.8,

                                        ),

                                      ),

                                      Text(

                                        '车牌号：${_plateNumber.isNotEmpty ? _plateNumber : "--"}',

                                        style: TextStyle(

                                          fontSize: 12,

                                          color: Colors.white

                                              .withValues(alpha: 0.7),

                                          height: 1.8,

                                        ),

                                      ),

                                      Text(

                                        '车架号：${_vin.isNotEmpty ? _vin : "--"}',

                                        style: TextStyle(

                                          fontSize: 12,

                                          color: Colors.white

                                              .withValues(alpha: 0.7),

                                          height: 1.8,

                                        ),

                                      ),

                                      const SizedBox(height: 4),

                                      GestureDetector(

                                        onTap: _showMoreCarInfo,

                                        child: const Text(

                                          '更多车辆信息',

                                          style: TextStyle(

                                            fontSize: 12,

                                            color: Colors.white,

                                            decoration:

                                                TextDecoration.underline,

                                            decorationColor: Colors.white,

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

                    ),

                  ),

          ),

        ],

      ),

    );

  }



  Widget _buildControlButton({

    required String activeIcon,

    required String inactiveIcon,

    required String label,

    required bool isActive,

    required VoidCallback onTap,

  }) {

    return GestureDetector(

      onTap: onTap,

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          Container(

            width: 72,

            height: 72,

            decoration: BoxDecoration(

              color: isActive

                  ? const Color(0xFF007AFF).withValues(alpha: 0.7)

                  : const Color(0xFF2B3136),

              shape: BoxShape.circle,

            ),

            child: Center(

              child: Image.asset(

                isActive ? inactiveIcon : activeIcon,

                width: 32,

                height: 32,

                fit: BoxFit.contain,

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildFeatureItem(String title) {

    return GestureDetector(

      onTap: () => _handleFeatureClick(title),

      child: Container(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

        child: Row(

          children: [

            Expanded(

              child: Text(

                title,

                style: const TextStyle(

                  color: Colors.white,

                  fontSize: 16,

                  fontWeight: FontWeight.normal,

                ),

              ),

            ),

            Image.asset(

              'assets/images/icons/arrow.png',

              width: 16,

              height: 16,

              fit: BoxFit.contain,

            ),

          ],

        ),

      ),

    );

  }



  void _handleFeatureClick(String title) {

    switch (title) {

      case '车辆诊断':

        _showDiagnosis();

        break;

      case '我的行程':

        _showTrips();

        break;

      case '全景照片':

        _showPanorama();

        break;

      case '操作记录':

        _showHistory();

        break;

      case '我的保险':

        _showInsurance();

        break;

    }

  }



  Widget _buildFeatureDialog({required String title, required Widget child}) {

    return Dialog(

      backgroundColor: const Color(0xFF1E2429),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Text(title,

                style: const TextStyle(

                    color: Colors.white,

                    fontSize: 18,)),

            const SizedBox(height: 16),

            child,

          ],

        ),

      ),

    );

  }



  Future<void> _showDiagnosis() async {

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (_) => _buildFeatureDialog(

        title: '车辆诊断',

        child: const Padding(

          padding: EdgeInsets.symmetric(vertical: 32),

          child: Column(

            children: [

              CircularProgressIndicator(color: Color(0xFF007AFF)),

              SizedBox(height: 16),

              Text('正在检测中...', style: TextStyle(color: Colors.white70)),

            ],

          ),

        ),

      ),

    );

    final resp = await _api.getDiagnosis();

    if (!mounted) return;

    Navigator.pop(context);

    if (resp.code == 0 && resp.data != null && resp.data['details'] != null) {

      final data = resp.data;

      final details = data['details'] as List;

      showDialog(

        context: context,

        builder: (_) => _buildFeatureDialog(

          title: '车辆诊断',

          child: SizedBox(

            width: double.maxFinite,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                  children: [

                    Column(children: [

                      Text('${data['score'] ?? '--'}',

                          style: const TextStyle(

                              color: Colors.white,

                              fontSize: 24,)),

                      const Text('评分',

                          style:

                              TextStyle(color: Colors.white54, fontSize: 12)),

                    ]),

                    Column(children: [

                      Text('${data['normalCount'] ?? 0}',

                          style: const TextStyle(

                              color: Color(0xFF4CAF50),

                              fontSize: 24,)),

                      const Text('正常',

                          style:

                              TextStyle(color: Colors.white54, fontSize: 12)),

                    ]),

                    Column(children: [

                      Text('${data['faultCount'] ?? 0}',

                          style: TextStyle(

                              color: (data['faultCount'] ?? 0) > 0

                                  ? const Color(0xFFF44336)

                                  : Colors.white,

                              fontSize: 24,)),

                      const Text('故障',

                          style:

                              TextStyle(color: Colors.white54, fontSize: 12)),

                    ]),

                  ],

                ),

                const SizedBox(height: 16),

                SizedBox(

                  height: 300,

                  child: ListView.builder(

                    itemCount: details.length,

                    itemBuilder: (_, i) {

                      final cat = details[i];

                      final items = cat['child'] as List? ?? [];

                      return Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Padding(

                            padding: const EdgeInsets.symmetric(vertical: 8),

                            child: Text(cat['itemName'] ?? '',

                                style: const TextStyle(

                                    color: Colors.white,

                                    fontSize: 14,)),

                          ),

                          ...items.map((item) => Padding(

                                padding:

                                    const EdgeInsets.symmetric(vertical: 4),

                                child: Row(

                                  mainAxisAlignment:

                                      MainAxisAlignment.spaceBetween,

                                  children: [

                                    Text(item['itemName'] ?? '',

                                        style: const TextStyle(

                                            color: Colors.white70,

                                            fontSize: 13)),

                                    Text(item['description'] ?? '',

                                        style: TextStyle(

                                            color: item['status'] == 'normal'

                                                ? const Color(0xFF4CAF50)

                                                : const Color(0xFFF44336),

                                            fontSize: 13)),

                                  ],

                                ),

                              )),

                        ],

                      );

                    },

                  ),

                ),

              ],

            ),

          ),

        ),

      );

    } else {

      showDialog(

        context: context,

        builder: (_) => _buildFeatureDialog(

          title: '车辆诊断',

          child: const Padding(

            padding: EdgeInsets.symmetric(vertical: 32),

            child: Text('暂无诊断数据', style: TextStyle(color: Colors.white54)),

          ),

        ),

      );

    }

  }



  Future<void> _showTrips() async {

    DateTime selectedDate = DateTime.now();

    String fmtDate(DateTime d) =>

        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';



    showDialog(

      context: context,

      builder: (ctx) {

        return StatefulBuilder(

          builder: (ctx, setDialogState) {

            Future<void> pickDate() async {

              final picked = await showDatePicker(

                context: ctx,

                initialDate: selectedDate,

                firstDate: DateTime(2020),

                lastDate: DateTime.now(),

                builder: (context, child) {

                  return Theme(

                    data: Theme.of(context).copyWith(

                      colorScheme: const ColorScheme.dark(

                        primary: Color(0xFF007AFF),

                        surface: Color(0xFF1E2429),

                      ),

                      dialogBackgroundColor: const Color(0xFF1E2429),

                    ),

                    child: child!,

                  );

                },

              );

              if (picked != null && picked != selectedDate) {

                setDialogState(() => selectedDate = picked);

              }

            }



            return Dialog(

              backgroundColor: const Color(0xFF1E2429),

              shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(16)),

              child: Padding(

                padding: const EdgeInsets.all(24),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    const Text('我的行程',

                        style: TextStyle(

                            color: Colors.white,

                            fontSize: 18,)),

                    const SizedBox(height: 12),

                    GestureDetector(

                      onTap: pickDate,

                      child: Container(

                        padding: const EdgeInsets.symmetric(

                            horizontal: 16, vertical: 10),

                        decoration: BoxDecoration(

                          color: const Color(0xFF2A3038),

                          borderRadius: BorderRadius.circular(8),

                        ),

                        child: Row(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            const Icon(Icons.calendar_today,

                                color: Color(0xFF007AFF), size: 18),

                            const SizedBox(width: 8),

                            Text(fmtDate(selectedDate),

                                style: const TextStyle(

                                    color: Colors.white, fontSize: 15)),

                            const SizedBox(width: 4),

                            const Icon(Icons.arrow_drop_down,

                                color: Colors.white54, size: 20),

                          ],

                        ),

                      ),

                    ),

                    const SizedBox(height: 16),

                    FutureBuilder(

                      future: _api.getDrivingHistory(

                          fmtDate(selectedDate), fmtDate(selectedDate)),

                      builder: (ctx, snapshot) {

                        if (snapshot.connectionState != ConnectionState.done) {

                          return const Padding(

                            padding: EdgeInsets.symmetric(vertical: 32),

                            child: Column(

                              children: [

                                CircularProgressIndicator(

                                    color: Color(0xFF007AFF)),

                                SizedBox(height: 16),

                                Text('加载?..',

                                    style: TextStyle(color: Colors.white70)),

                              ],

                            ),

                          );

                        }

                        final resp = snapshot.data;

                        final List records;

                        if (resp != null &&

                            resp.code == 0 &&

                            resp.data != null &&

                            resp.data is List) {

                          records = resp.data as List;

                        } else {

                          records = [];

                        }

                        double totalMileage = 0;

                        int totalMinutes = 0;

                        for (final r in records) {

                          totalMileage += (r['mileage'] ?? 0).toDouble();

                          totalMinutes +=

                              ((r['spendTime'] ?? 0) as num).toInt();

                        }

                        final hours = totalMinutes ~/ 60;

                        final mins = totalMinutes % 60;

                        final totalTime = hours > 0

                            ? '$hours:${mins.toString().padLeft(2, '0')}'

                            : '$mins';

                        return Column(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Row(

                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                              children: [

                                Column(children: [

                                  Text(totalMileage.toStringAsFixed(1),

                                      style: const TextStyle(

                                          color: Colors.white,

                                          fontSize: 24,)),

                                  const Text('里程(km)',

                                      style: TextStyle(

                                          color: Colors.white54, fontSize: 12)),

                                ]),

                                Column(children: [

                                  Text(totalTime,

                                      style: const TextStyle(

                                          color: Colors.white,

                                          fontSize: 24,)),

                                  const Text('总耗时',

                                      style: TextStyle(

                                          color: Colors.white54, fontSize: 12)),

                                ]),

                              ],

                            ),

                            const SizedBox(height: 16),

                            if (records.isNotEmpty)

                              SizedBox(

                                height: 200,

                                child: ListView.builder(

                                  itemCount: records.length,

                                  itemBuilder: (_, i) {

                                    final r = records[i];

                                    final startTime =

                                        (r['startTime'] ?? '').split(' ').last;

                                    final endTime =

                                        (r['endTime'] ?? '').split(' ').last;

                                    return Column(

                                      children: [

                                        Padding(

                                          padding: const EdgeInsets.symmetric(

                                              vertical: 8),

                                          child: Column(

                                            children: [

                                              Row(

                                                children: [

                                                  const Icon(Icons.circle,

                                                      size: 6,

                                                      color: Color(0xFF4CAF50)),

                                                  const SizedBox(width: 6),

                                                  Text(

                                                      startTime.length >= 5

                                                          ? startTime.substring(

                                                              0, 5)

                                                          : startTime,

                                                      style: const TextStyle(

                                                          color: Colors.white54,

                                                          fontSize: 12)),

                                                  const SizedBox(width: 8),

                                                  Expanded(

                                                    child: Text(

                                                        r['startAddressName'] ??

                                                            '未知',

                                                        style: const TextStyle(

                                                            color: Colors.white,

                                                            fontSize: 13)),

                                                  ),

                                                ],

                                              ),

                                              const SizedBox(height: 6),

                                              Row(

                                                children: [

                                                  const Icon(Icons.circle,

                                                      size: 6,

                                                      color: Color(0xFF007AFF)),

                                                  const SizedBox(width: 6),

                                                  Text(

                                                      endTime.length >= 5

                                                          ? endTime.substring(

                                                              0, 5)

                                                          : endTime,

                                                      style: const TextStyle(

                                                          color: Colors.white54,

                                                          fontSize: 12)),

                                                  const SizedBox(width: 8),

                                                  Expanded(

                                                    child: Text(

                                                        r['endAddressName'] ??

                                                            '未知',

                                                        style: const TextStyle(

                                                            color: Colors.white,

                                                            fontSize: 13)),

                                                  ),

                                                  Text(

                                                      '${r['mileage'] ?? 0} km',

                                                      style: const TextStyle(

                                                          color: Colors.white54,

                                                          fontSize: 12)),

                                                ],

                                              ),

                                            ],

                                          ),

                                        ),

                                        if (i < records.length - 1)

                                          const Divider(

                                              height: 1,

                                              color: Color(0xFF2A3038)),

                                      ],

                                    );

                                  },

                                ),

                              )

                            else

                              const Padding(

                                padding: EdgeInsets.symmetric(vertical: 16),

                                child: Text('当日无行驶记录',

                                    style: TextStyle(color: Colors.white54)),

                              ),

                          ],

                        );

                      },

                    ),

                  ],

                ),

              ),

            );

          },

        );

      },

    );

  }



  Future<void> _showPanorama() async {

    showDialog(

      context: context,

      builder: (ctx) {

        return StatefulBuilder(

          builder: (ctx, setDialogState) {

            Future<void> loadPhotos() async {

              final resp = await _api.getPanoramaPhotos();

              return;

            }



            return Dialog(

              backgroundColor: const Color(0xFF1E2429),

              shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(16)),

              child: Padding(

                padding: const EdgeInsets.all(24),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    const Text('全景照片',

                        style: TextStyle(

                            color: Colors.white,

                            fontSize: 18,)),

                    const SizedBox(height: 12),

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: () async {

                          _showNotification('拍照指令发送中...');

                          final r = await _executeWithPinCheck('photograph');

                          _showNotification(

                              r.code == 0 ? '已发送，正在刷新...' : '发送失败');;

                          if (r.code == 0) {

                            await Future.delayed(const Duration(seconds: 3));

                            setDialogState(() {});

                          }

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: const Color(0xFF007AFF),

                          shape: RoundedRectangleBorder(

                              borderRadius: BorderRadius.circular(8)),

                        ),

                        child: const Text('获取新照片',

                            style: TextStyle(color: Colors.white)),

                      ),

                    ),

                    const SizedBox(height: 12),

                    FutureBuilder(

                      future: _api.getPanoramaPhotos(),

                      builder: (ctx, snapshot) {

                        if (snapshot.connectionState != ConnectionState.done) {

                          return const Padding(

                            padding: EdgeInsets.symmetric(vertical: 32),

                            child: Column(

                              children: [

                                CircularProgressIndicator(

                                    color: Color(0xFF007AFF)),

                                SizedBox(height: 16),

                                Text('加载?..',

                                    style: TextStyle(color: Colors.white70)),

                              ],

                            ),

                          );

                        }

                        final resp = snapshot.data;

                        List photos = [];

                        if (resp != null &&

                            resp.code == 0 &&

                            resp.data != null &&

                            resp.data is List) {

                          photos = resp.data as List;

                        }

                        if (photos.isEmpty) {

                          return const Padding(

                            padding: EdgeInsets.symmetric(vertical: 32),

                            child: Text('暂无照片',

                                style: TextStyle(color: Colors.white54)),

                          );

                        }

                        // ?task_id ?id 分组（同一次拍摄）

                        final Map<String, List> groups = {};

                        for (final p in photos) {

                          final key =

                              (p['task_id'] ?? p['id'] ?? 'unknown').toString();

                          groups.putIfAbsent(key, () => []).add(p);

                        }

                        final groupList = groups.values.toList();

                        final dirMap = {'F': '前', 'R': '后', 'P': '左', 'D': '右'};

                        return Column(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Text('共 ${photos.length} 张',

                                style: const TextStyle(

                                    color: Colors.white54, fontSize: 12)),

                            const SizedBox(height: 8),

                            SizedBox(

                              height: 300,

                              child: ListView.builder(

                                itemCount: groupList.length,

                                itemBuilder: (_, gi) {

                                  final group = groupList[gi];

                                  final time = group[0]['time'] ?? '';

                                  final timeStr =

                                      time.toString().replaceAll('.0', '');

                                  return Column(

                                    crossAxisAlignment:

                                        CrossAxisAlignment.start,

                                    children: [

                                      if (timeStr.isNotEmpty)

                                        Padding(

                                          padding: const EdgeInsets.only(

                                              bottom: 6, top: 4),

                                          child: Text(

                                              timeStr.length >= 16

                                                  ? timeStr.substring(0, 16)

                                                  : timeStr,

                                              style: const TextStyle(

                                                  color: Colors.white54,

                                                  fontSize: 12)),

                                        ),

                                      GridView.builder(

                                        shrinkWrap: true,

                                        physics:

                                            const NeverScrollableScrollPhysics(),

                                        gridDelegate:

                                            const SliverGridDelegateWithFixedCrossAxisCount(

                                                crossAxisCount: 4,

                                                crossAxisSpacing: 4,

                                                mainAxisSpacing: 4),

                                        itemCount: group.length,

                                        itemBuilder: (_, pi) {

                                          final p = group[pi];

                                          final match = RegExp(r'_([FRBLPD])_')

                                              .firstMatch(p['name'] ?? '');

                                          final dir = match != null

                                              ? (dirMap[match.group(1)] ?? '')

                                              : '';

                                          return GestureDetector(

                                            onTap: () {

                                              final url = p['url'] ??

                                                  p['thumbnail'] ??

                                                  '';

                                              if (url.isNotEmpty) {

                                                showDialog(

                                                  context: ctx,

                                                  builder: (_) => Dialog(

                                                    backgroundColor:

                                                        Colors.black,

                                                    insetPadding:

                                                        EdgeInsets.zero,

                                                    child: GestureDetector(

                                                      onTap: () =>

                                                          Navigator.pop(ctx),

                                                      child: InteractiveViewer(

                                                        child: Image.network(

                                                          url,

                                                          fit: BoxFit.contain,

                                                          errorBuilder: (_, __,

                                                                  ___) =>

                                                              const Center(

                                                                  child: Text(

                                                                      '加载失败',

                                                                      style: TextStyle(

                                                                          color:

                                                                              Colors.white54))),

                                                        ),

                                                      ),

                                                    ),

                                                  ),

                                                );

                                              }

                                            },

                                            child: Stack(

                                              children: [

                                                ClipRRect(

                                                  borderRadius:

                                                      BorderRadius.circular(4),

                                                  child: Image.network(

                                                      p['thumbnail'] ?? '',

                                                      width: double.infinity,

                                                      height: double.infinity,

                                                      fit: BoxFit.cover,

                                                      errorBuilder: (_, __,

                                                              ___) =>

                                                          Container(

                                                              color: const Color(

                                                                  0xFF333333))),

                                                ),

                                                if (dir.isNotEmpty)

                                                  Positioned(

                                                    bottom: 2,

                                                    left: 2,

                                                    child: Container(

                                                      padding: const EdgeInsets

                                                          .symmetric(

                                                          horizontal: 4,

                                                          vertical: 1),

                                                      decoration: BoxDecoration(

                                                          color: Colors.black54,

                                                          borderRadius:

                                                              BorderRadius

                                                                  .circular(3)),

                                                      child: Text(dir,

                                                          style:

                                                              const TextStyle(

                                                                  color: Colors

                                                                      .white,

                                                                  fontSize:

                                                                      10)),

                                                    ),

                                                  ),

                                              ],

                                            ),

                                          );

                                        },

                                      ),

                                      if (gi < groupList.length - 1)

                                        const SizedBox(height: 12),

                                    ],

                                  );

                                },

                              ),

                            ),

                          ],

                        );

                      },

                    ),

                  ],

                ),

              ),

            );

          },

        );

      },

    );

  }



  Widget _buildMapWebView() {

    if (_mapWidget != null) {

      // 位置变化时用 JS 更新

      _mapController?.runJavaScript('''

        if (typeof map !== 'undefined') {

          map.setCenter([$_locationLng, $_locationLat]);

          if (typeof window._marker !== 'undefined') {

            window._marker.setPosition([$_locationLng, $_locationLat]);

          }

        }

      ''');

      return _mapWidget!;

    }



    final mapHtml = '''

<!DOCTYPE html>

<html>

<head>

<meta charset="utf-8">

<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">

<style>

  html, body, #map { margin:0; padding:0; width:100%; height:100%; }

  .amap-logo, .amap-copyright { display:none !important; }

</style>

</head>

<body>

<div id="map"></div>

<script src="https://webapi.amap.com/maps?v=2.0&key=d994dd4df0ea0c29d42fd092591853ef"></script>

<script>

  var map = new AMap.Map('map', {

    zoom: 18,

    center: [$_locationLng, $_locationLat],

    mapStyle: 'amap://styles/dark',

    touchZoom: false,

    scrollWheel: false,

    doubleClickZoom: false,

    dragEnable: false,

    rotateEnable: false,

    pitchEnable: false,

    zoomEnable: false

  });

  window._marker = new AMap.Marker({

    position: [$_locationLng, $_locationLat],

    content: '<div style="width:16px;height:24px;"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 24"><path d="M8 0C3.6 0 0 3.6 0 8c0 6 8 16 8 16s8-10 8-16C16 3.6 12.4 0 8 0z" fill="#2196F3"/><circle cx="8" cy="8" r="3.5" fill="#fff"/></svg></div>',

    offset: new AMap.Pixel(-8, -24)

  });

  window._marker.setMap(map);

</script>

</body>

</html>''';



    _mapController = WebViewController()

      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      ..setBackgroundColor(const Color(0xFF2B3136))

      ..loadHtmlString(mapHtml);

    _mapWidget =

        IgnorePointer(child: WebViewWidget(controller: _mapController!));

    return _mapWidget!;

  }



  Future<void> _fetchLocation() async {

    try {

      final resp = await _api.getCarLocation();

      if (resp.code == 0 && resp.data != null && resp.data is Map) {

        final data = resp.data;

        final lng = (data['lng'] ?? 0).toDouble();

        final lat = (data['lat'] ?? 0).toDouble();

        setState(() {

          _locationLng = lng;

          _locationLat = lat;

          _locationAddr = data['addrDesc'] ?? '';

          _locationRoad = data['roadName'] ?? '';

        });

        _reverseGeocode(lng, lat);

      }

    } catch (_) {}

  }



  Future<void> _reverseGeocode(double lng, double lat) async {

    if (lng == 0 || lat == 0) return;

    try {

      const key = 'd994dd4df0ea0c29d42fd092591853ef';

      final url =

          'https://restapi.amap.com/v3/geocode/regeo?location=$lng,$lat&key=$key&extensions=base';

      final dio = Dio();

      final resp = await dio.get(url);

      if (resp.statusCode == 200 && resp.data is Map) {

        final data = resp.data;

        if (data['status'] == '1' && data['regeocode'] != null) {

          final regeo = data['regeocode'];

          final address = regeo['formatted_address'] ?? '';

          final street =

              regeo['addressComponent']?['streetNumber']?['street'] ?? '';

          setState(() {

            _locationAddr = address;

            if (street.isNotEmpty) _locationRoad = street;

          });

        }

      }

    } catch (_) {}

  }



  void _showMoreCarInfo() {

    showModalBottomSheet(

      context: context,

      backgroundColor: const Color(0xFF1E2429),

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),

      ),

      isScrollControlled: true,

      builder: (ctx) {

        return Padding(

          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const Text('车辆信息',

                  style: TextStyle(

                      color: Colors.white,

                      fontSize: 18,)),

              const SizedBox(height: 16),

              _buildInfoRow('车辆名称', _carName, editable: true, onTap: () {

                Navigator.pop(ctx);

                _editCarName();

              }),

              _buildInfoRow(

                  '车牌号', _plateNumber.isNotEmpty ? _plateNumber : '未设置',

                  editable: true, onTap: () {

                Navigator.pop(ctx);

                _editPlateNumber();

              }),

              _buildInfoRow('车架号', _vin.isNotEmpty ? _vin : '未知'),

              _buildInfoRow('型号', _seriesName.isNotEmpty ? _seriesName : '未知'),

              _buildInfoRow('控车码', '管理', onTap: () => _showControlCodeDialog()),

              _buildInfoRow('用车权益', '基础权益'),

            ],

          ),

        );

      },

    );

  }



  Widget _buildInfoRow(String label, String value,

      {bool editable = false, VoidCallback? onTap}) {

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            if (editable || onTap != null)
              const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );

  }



  void _editCarName() {

    final controller = TextEditingController(text: _carName);

    showDialog(

      context: context,

      builder: (ctx) => Dialog(

        backgroundColor: const Color(0xFF1E2429),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('修改车辆名称',

                  style: TextStyle(

                      color: Colors.white,

                      fontSize: 18,)),

              const SizedBox(height: 16),

              TextField(

                controller: controller,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(

                  filled: true,

                  fillColor: const Color(0xFF2A3038),

                  border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(8),

                      borderSide: BorderSide.none),

                  hintText: '请输入车辆名',

                  hintStyle: const TextStyle(color: Colors.white38),

                ),

              ),

              const SizedBox(height: 16),

              Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  TextButton(

                    onPressed: () => Navigator.pop(ctx),

                    child: const Text('取消',

                        style: TextStyle(color: Colors.white54)),

                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(

                    onPressed: () async {

                      final name = controller.text.trim();

                      if (name.isEmpty || name == _carName) {

                        Navigator.pop(ctx);

                        return;

                      }

                      Navigator.pop(ctx);

                      final resp = await _api.updateCar(carName: name);

                      if (resp.code == 0) {

                        setState(() => _carName = name);

                        _showNotification('车辆名称修改成功');

                      } else {

                        _showNotification('修改失败?{resp.msg ?? "未知错误"}');

                      }

                    },

                    style: ElevatedButton.styleFrom(

                      backgroundColor: const Color(0xFF007AFF),

                      shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(8)),

                    ),

                    child:

                        const Text('确定', style: TextStyle(color: Colors.white)),

                  ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }



  void _editPlateNumber() {

    final controller = TextEditingController(text: _plateNumber);

    showDialog(

      context: context,

      builder: (ctx) => Dialog(

        backgroundColor: const Color(0xFF1E2429),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('修改车牌',

                  style: TextStyle(

                      color: Colors.white,

                      fontSize: 18,)),

              const SizedBox(height: 16),

              TextField(

                controller: controller,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(

                  filled: true,

                  fillColor: const Color(0xFF2A3038),

                  border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(8),

                      borderSide: BorderSide.none),

                  hintText: '请输入车牌号',

                  hintStyle: const TextStyle(color: Colors.white38),

                ),

              ),

              const SizedBox(height: 16),

              Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  TextButton(

                    onPressed: () => Navigator.pop(ctx),

                    child: const Text('取消',

                        style: TextStyle(color: Colors.white54)),

                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(

                    onPressed: () async {

                      final plate = controller.text.trim();

                      if (plate.isEmpty || plate == _plateNumber) {

                        Navigator.pop(ctx);

                        return;

                      }

                      Navigator.pop(ctx);

                      final resp = await _api.updateCar(plateNumber: plate);

                      if (resp.code == 0) {

                        setState(() => _plateNumber = plate);

                        _showNotification('车牌号修改成');

                      } else {

                        _showNotification('修改失败?{resp.msg ?? "未知错误"}');

                      }

                    },

                    style: ElevatedButton.styleFrom(

                      backgroundColor: const Color(0xFF007AFF),

                      shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(8)),

                    ),

                    child:

                        const Text('确定', style: TextStyle(color: Colors.white)),

                  ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }



  void _showControlCodeDialog() {
    bool pinEnabled = false;
    bool isLoading = true;
    bool presetPinEnabled = false;
    final presetPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          if (isLoading) {
            _api.getPinStatus().then((resp) {
              if (!ctx.mounted) return;
              setState(() {
                isLoading = false;
                if (resp.code == 0 && resp.data != null) {
                  pinEnabled = resp.data['pinSwitch'] == true;
                }
              });
            });
            SharedPreferences.getInstance().then((prefs) {
              if (!ctx.mounted) return;
              final enabled = prefs.getBool('preset_pin_enabled') ?? false;
              final value = prefs.getString('preset_pin_value') ?? '';
              setState(() {
                presetPinEnabled = enabled;
                presetPinController.text = value;
              });
            });
          }

          return Dialog(
            backgroundColor: const Color(0xFF1E2429),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('控车码管理',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                    )
                  else ...[
                    // 控车码开关
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3038),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: Colors.white70, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('控车码开关',
                                style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final newValue = !pinEnabled;
                              if (newValue) {
                                // 开启：直接调用
                                final resp = await _api.updatePinStatus(true);
                                if (!ctx.mounted) return;
                                if (resp.code == 0) {
                                  setState(() => pinEnabled = true);
                                  _showNotification('控车码已开启');
                                } else {
                                  _showNotification('开启失败: ${resp.msg ?? "未知错误"}');
                                }
                              } else {
                                // 关闭：先发短信验证码
                                Navigator.pop(ctx);
                                _showSmsVerifyDialog();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: pinEnabled
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF555555),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 200),
                                alignment: pinEnabled
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 预设免输密码
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3038),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.vpn_key_outlined, color: Colors.white70, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('预设免输密码',
                                    style: TextStyle(color: Colors.white, fontSize: 16)),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  if (presetPinEnabled) {
                                    await prefs.setBool('preset_pin_enabled', false);
                                    setState(() => presetPinEnabled = false);
                                  } else {
                                    if (presetPinController.text.length == 6) {
                                      await prefs.setBool('preset_pin_enabled', true);
                                      await prefs.setString('preset_pin_value', presetPinController.text);
                                      setState(() => presetPinEnabled = true);
                                      _showNotification('预设控车码已开启');
                                    } else {
                                      _showNotification('请输入6位控车码');
                                    }
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 52,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: presetPinEnabled
                                        ? const Color(0xFF007AFF)
                                        : const Color(0xFF555555),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: presetPinEnabled
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: presetPinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 6,
                            style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 4),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1E2429),
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              hintText: '输入6位控车码（本地保存）',
                              hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 0, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('关闭', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 短信验证码弹窗（关闭控车码时使用）
  void _showSmsVerifyDialog() {
    final smsCodeController = TextEditingController();
    bool isSending = false;
    int countdown = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // 自动发送验证码
          if (!isSending && countdown == 0 && smsCodeController.text.isEmpty) {
            isSending = true;
            _api.sendControlCodeSms().then((resp) {
              if (!ctx.mounted) return;
              setState(() {
                isSending = false;
                if (resp.code == 0) {
                  countdown = 60;
                }
              });
              // 开始倒计时
              if (countdown > 0) {
                Future.doWhile(() async {
                  await Future.delayed(const Duration(seconds: 1));
                  if (!ctx.mounted) return false;
                  setState(() => countdown--);
                  return countdown > 0;
                });
              }
            });
          }

          return Dialog(
            backgroundColor: const Color(0xFF1E2429),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('验证身份',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('验证码已发送至 ${_api.phone ?? "您的手机"}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: smsCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2A3038),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '输入验证码',
                      hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消', style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final code = smsCodeController.text.trim();
                            if (code.isEmpty) return;
                            Navigator.pop(ctx);
                            final resp = await _api.updatePinStatus(false, authCode: code);
                            if (resp.code == 0) {
                              _showNotification('控车码已关闭');
                              _showControlCodeDialog();
                            } else {
                              _showNotification('关闭失败: ${resp.msg ?? "未知错误"}');
                              _showControlCodeDialog();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('确认关闭', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showHistory() async {

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (_) => _buildFeatureDialog(

        title: '操作记录',

        child: const Padding(

          padding: EdgeInsets.symmetric(vertical: 32),

          child: Column(

            children: [

              CircularProgressIndicator(color: Color(0xFF007AFF)),

              SizedBox(height: 16),

              Text('加载?..', style: TextStyle(color: Colors.white70)),

            ],

          ),

        ),

      ),

    );

    final resp = await _api.getControlHistory();

    if (!mounted) return;

    Navigator.pop(context);

    if (resp.code == 0 && resp.data != null && resp.data['data'] != null) {

      final items = resp.data['data'] as List;

      showDialog(

        context: context,

        builder: (_) => _buildFeatureDialog(

          title: '操作记录',

          child: items.isNotEmpty

              ? SizedBox(

                  height: 300,

                  child: ListView.builder(

                    itemCount: items.length,

                    itemBuilder: (_, i) {

                      final item = items[i];

                      final time =

                          (item['cmdSendTime'] ?? '').replaceAll('.0', '');

                      return Padding(

                        padding: const EdgeInsets.symmetric(vertical: 6),

                        child: Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            Expanded(

                              child: Text(

                                  item['cmdDescription'] ??

                                      item['tboxCmd'] ??

                                      '',

                                  style: const TextStyle(

                                      color: Colors.white, fontSize: 13),

                                  overflow: TextOverflow.ellipsis),

                            ),

                            Text(

                                time.length >= 16

                                    ? time.substring(0, 16)

                                    : time,

                                style: const TextStyle(

                                    color: Colors.white54, fontSize: 12)),

                          ],

                        ),

                      );

                    },

                  ),

                )

              : const Padding(

                  padding: EdgeInsets.symmetric(vertical: 32),

                  child:

                      Text('暂无操作记录', style: TextStyle(color: Colors.white54)),

                ),

        ),

      );

    } else {

      showDialog(

        context: context,

        builder: (_) => _buildFeatureDialog(

          title: '操作记录',

          child: const Padding(

            padding: EdgeInsets.symmetric(vertical: 32),

            child: Text('暂无操作记录', style: TextStyle(color: Colors.white54)),

          ),

        ),

      );

    }

  }



  void _showInsurance() {

    showDialog(

      context: context,

      builder: (_) => _buildFeatureDialog(

        title: '我的保险',

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                const Text('保险公司',

                    style: TextStyle(color: Colors.white70, fontSize: 14)),

                Text(_insuranceCompany,

                    style: const TextStyle(color: Colors.white, fontSize: 14)),

              ],

            ),

            const SizedBox(height: 12),

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                const Text('客服电话',

                    style: TextStyle(color: Colors.white70, fontSize: 14)),

                Text(_insurancePhone,

                    style: const TextStyle(color: Colors.white, fontSize: 14)),

              ],

            ),

            const SizedBox(height: 24),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton(

                onPressed: () => Navigator.pop(context),

                style: ElevatedButton.styleFrom(

                  backgroundColor: const Color(0xFF007AFF),

                  shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(12)),

                  padding: const EdgeInsets.symmetric(vertical: 14),

                ),

                child: const Text('续保',

                    style: TextStyle(color: Colors.white, fontSize: 16)),

              ),

            ),

          ],

        ),

      ),

    );

  }

}

