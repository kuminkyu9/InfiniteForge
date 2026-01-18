import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'components/image_button.dart';

void main() {
  runApp(GameWidget(game: ForgeGame()));
}

class ForgeGame extends FlameGame {
  // --- Constants & Config ---
  static const String baseUrl = 'http://10.0.2.2:5103/api';
  static const TextStyle _headerTextStyle = TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold);
  static const TextStyle _infoGoldStyle = TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold, height: 1.5);
  static const TextStyle _infoCostStyle = TextStyle(color: Color(0xFFFF6666), fontSize: 20, fontWeight: FontWeight.bold, height: 1.5);

  final Dio _dio = Dio();
  
  // --- Game State ---
  int _userId = 0;
  int _gold = 0;
  int _level = 1;

  // 실시간 계산 변수 (서버 동기화 필요)
  int _profitPerSec = 1;     
  int _cost = 1000;          
  DateTime _lastCollectionTime = DateTime.now();

  // --- UI Components ---
  late TextComponent _goldText;
  late TextComponent _levelText;
  late TextComponent _statusText;
  late TextBoxComponent _accumulatedGoldText;
  late TextBoxComponent _upgradeCostText;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. 리소스 로드
    // await images.loadAll([
    //   'assets/ui/blacksmith_wallpaper.png', 
    //   'assets/ui/user_gold_ui.png', 
    //   'assets/ui/user_sword_ui.png', 
    //   'assets/ui/get_gold_btn_ui.png', 
    //   'assets/ui/upgrade_btn_ui.png',
    // ]);

    // 1. UI 이미지 리스트
    final uiImages = [
      'ui/blacksmith_wallpaper.png', // 경로가 assets/images/ui/ 라면
      'ui/user_gold_ui.png',
      'ui/user_sword_ui.png',
      'ui/get_gold_btn_ui.png',
      'ui/upgrade_btn_ui.png',
    ];
    // 2. 검 이미지 리스트 자동 생성 (sword_01.png ~ sword_90.png)
    final swordImages = List.generate(90, (index) {
      // index는 0부터 시작하므로 +1
      int num = index + 1;
      // 1 -> "01", 10 -> "10" 처럼 두 자리로 맞춤
      String formattedNum = num.toString().padLeft(2, '0'); 
      return 'swords/sword_$formattedNum.png'; // 경로 확인 필요!
    });
    // 3. 합쳐서 한 번에 로드
    await images.loadAll([...uiImages, ...swordImages]);

    // 2. UI 초기화 (메서드 분리)
    _initBackground();
    _initHeaderUI();
    _initCenterDisplay(); // 검 이미지 영역
    _initInfoPanel();     // 정보 텍스트 패널
    _initFooterButtons(); // 하단 버튼

    // 3. 서버 로그인
    _login();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 실시간 골드 및 비용 업데이트
    final income = DateTime.now().difference(_lastCollectionTime).inSeconds * _profitPerSec;
    _accumulatedGoldText.text = '모인 골드\n+$income';
    _upgradeCostText.text = '강화 비용\n-$_cost';
  }

  // ==========================================
  //               UI Initialization
  // ==========================================

  void _initBackground() {
    final bgSprite = Sprite(images.fromCache('ui/blacksmith_wallpaper.png'));
    double scale = size.x / bgSprite.originalSize.x;
    if (bgSprite.originalSize.y * scale < size.y) {
      scale = size.y / bgSprite.originalSize.y;
    }
    
    add(SpriteComponent(
      sprite: bgSprite,
      anchor: Anchor.center,
      position: size / 2,
      scale: Vector2.all(scale),
    ));
  }

  void _initHeaderUI() {
    // 골드 바 (좌측)
    final goldSprite = Sprite(images.fromCache('ui/user_gold_ui.png'));
    final goldSize = Vector2(160.0, 160.0 * (goldSprite.originalSize.y / goldSprite.originalSize.x));
    
    final goldBar = SpriteComponent(
      sprite: goldSprite,
      position: Vector2(10, 30),
      size: goldSize,
    );
    
    _goldText = TextComponent(
      text: '0',
      anchor: Anchor.centerRight,
      position: Vector2(goldSize.x - 20, goldSize.y / 2),
      textRenderer: TextPaint(style: _headerTextStyle),
    );
    goldBar.add(_goldText);
    add(goldBar);

    // 레벨 바 (우측)
    final levelSprite = Sprite(images.fromCache('ui/user_sword_ui.png'));
    final levelSize = Vector2(150.0, 150.0 * (levelSprite.originalSize.y / levelSprite.originalSize.x));
    
    final levelBar = SpriteComponent(
      sprite: levelSprite,
      position: Vector2(size.x - 10, 30),
      anchor: Anchor.topRight,
      size: levelSize,
    );
    
    _levelText = TextComponent(
      text: 'Lv.1',
      anchor: Anchor.centerRight,
      position: Vector2(levelSize.x - 20, levelSize.y / 2),
      textRenderer: TextPaint(style: _headerTextStyle.copyWith(fontSize: 28)),
    );
    levelBar.add(_levelText);
    add(levelBar);
  }

  void _initCenterDisplay() {
    // 중앙 검 표시 영역 (임시 박스)
    add(RectangleComponent(
      position: Vector2(size.x / 2, size.y * 0.5),
      size: Vector2(200, 400),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.grey.withValues(alpha: 0.3),
    ));

    // 상태 메시지
    _statusText = TextComponent(
      text: 'Connecting...',
      position: Vector2(size.x / 2, size.y * 0.75),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white54, fontSize: 16)),
    );
    add(_statusText);
  }

  void _initInfoPanel() {
    double infoY = size.y * 0.78;
    
    // 배경 패널
    add(RectangleComponent(
      position: Vector2(size.x / 2, infoY),
      size: Vector2(size.x * 0.9, 80),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.black.withValues(alpha: 0.5),
    ));

    // 모인 골드 (좌측)
    _accumulatedGoldText = TextBoxComponent(
      text: '모인 골드\n+0',
      position: Vector2(size.x * 0.25, infoY),
      anchor: Anchor.center,
      size: Vector2(200, 100),
      align: Anchor.center,
      textRenderer: TextPaint(style: _infoGoldStyle),
      priority: 10,
    );
    add(_accumulatedGoldText);

    // 강화 비용 (우측)
    _upgradeCostText = TextBoxComponent(
      text: '강화 비용\n-1000',
      position: Vector2(size.x * 0.75, infoY),
      anchor: Anchor.center,
      size: Vector2(200, 100),
      align: Anchor.center,
      textRenderer: TextPaint(style: _infoCostStyle),
      priority: 10,
    );
    add(_upgradeCostText);
  }

  void _initFooterButtons() {
    double btnY = size.y * 0.88;
    double btnWidth = 180.0;
    double btnHeight = 70.0;

    // Collect Button
    add(ImageButton(
      imageName: 'ui/get_gold_btn_ui.png',
      position: Vector2(size.x * 0.25, btnY),
      size: Vector2(btnWidth, btnHeight),
      label: "",
      onTap: _collect,
    ));

    // Upgrade Button
    add(ImageButton(
      imageName: 'ui/upgrade_btn_ui.png',
      position: Vector2(size.x * 0.75, btnY),
      size: Vector2(btnWidth, btnHeight),
      label: "",
      onTap: _upgrade,
    ));
  }

  // ==========================================
  //               API Logic
  // ==========================================

  Future<void> _login() async {
    try {
      final res = await _dio.post('$baseUrl/auth/login', data: {'deviceId': 'layout_fix_v1'});
      _userId = res.data['id'];
      
      // 데이터 동기화
      // 무조건 현재시간(now)으로 초기화하던 것을 서버 시간으로 변경
      // 서버는 UTC로 보내주므로, toLocal()로 내 핸드폰 시간대와 맞춰야 함
      if (res.data['lastCollectedAt'] != null) {
        _lastCollectionTime = DateTime.parse(res.data['lastCollectedAt']).toLocal();
      } else {
        _lastCollectionTime = DateTime.now();
      }

      _cost = res.data['upgradeCost'] ?? 1000; 
      _profitPerSec = res.data['profitPerSec'] ?? (_level * 10);

      updateUI(res.data['gold'], res.data['swordLevel'], "Ready to Forge");
    } catch (e) {
      _statusText.text = "Server Error: ${e.toString()}";
    }
  }

  Future<void> _upgrade() async {
    if (_userId == 0) return;
    try {
      final res = await _dio.post('$baseUrl/game/upgrade', data: {'userId': _userId});
      bool success = res.data['success'];

      if (success) {
        _cost = res.data['nextUpgradeCost'] ?? (_cost * 1.5).toInt();
        _profitPerSec = res.data['newProfitPerSec'] ?? (res.data['newLevel'] * 10);
      }

      updateUI(res.data['currentGold'], res.data['newLevel'], success ? "SUCCESS!" : "Failed...");
    } catch (e) {
      _statusText.text = "Not enough Gold";
    }
  }

  Future<void> _collect() async {
    if (_userId == 0) return;
    try {
      final res = await _dio.post('$baseUrl/game/collect', data: {'userId': _userId});

      _lastCollectionTime = DateTime.now(); // 시간 초기화
      updateUI(res.data['currentGold'], _level, "+${res.data['earned']} Gold");
    } catch (e) {
      _statusText.text = "Too fast...";
    }
  }

  void updateUI(int gold, int level, String msg) {
    _gold = gold;
    _level = level;
    _goldText.text = '$_gold';
    _levelText.text = '$_level';
    _statusText.text = msg;
  }
}