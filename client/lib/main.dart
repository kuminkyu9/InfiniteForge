import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(GameWidget(game: ForgeGame()));
}

class ForgeGame extends FlameGame {
  static const String baseUrl = 'http://10.0.2.2:5103/api';
  final Dio _dio = Dio();
  
  int _userId = 0;
  int _gold = 0;
  int _level = 1;

  // 실시간 계산 및 UI 표시를 위한 변수들
  int _profitPerSec = 1;      // 초당 골드 생산량 (서버에서 받아와야 함)
  int _cost = 1000;           // 다음 강화 비용 (서버에서 받아와야 함)
  DateTime _lastCollectionTime = DateTime.now(); // 마지막 수령 시간

  late TextComponent _goldText;
  late TextComponent _levelText;
  late TextComponent _statusText;

  late TextComponent _accumulatedGoldText; // "모인 골드" 표시
  late TextComponent _upgradeCostText;     // "강화 비용" 표시

  @override
  void update(double dt) {
    super.update(dt);

    // 1. 모인 골드 계산 (시간 * 초당 생산량)
    final now = DateTime.now();
    final diff = now.difference(_lastCollectionTime).inSeconds;
    final income = diff * _profitPerSec;

    _accumulatedGoldText.text = '모인 골드\n+$income';

    // 2. 강화 비용 업데이트 (레벨업 후 비용이 바뀌므로)
    _upgradeCostText.text = '강화 비용\n-$_cost';
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 이미지 미리 로딩
    await images.loadAll(['blacksmith_wallpaper.png', 'user_gold_ui.png', 'user_sword_ui.png', 'get_gold_btn_ui.png', 'upgrade_btn_ui.png']);

    // [배경] 비율 유지하며 꽉 채우기 (Crop 효과)
    final bgSprite = Sprite(images.fromCache('blacksmith_wallpaper.png'));
    double scale = size.x / bgSprite.originalSize.x;
    // 만약 세로가 빈다면 세로 기준으로 맞춤
    if (bgSprite.originalSize.y * scale < size.y) {
      scale = size.y / bgSprite.originalSize.y;
    }
    add(SpriteComponent(
      sprite: bgSprite,
      anchor: Anchor.center, // 중앙 기준
      position: size / 2,    // 화면 중앙에 배치
      scale: Vector2.all(scale), // 비율 유지하며 확대
    ));

    // [헤더 UI 공통 설정] 크기 키우기 (가로 200)
    double goldUiWidth = 160.0; 
    double swordUiWidth = 150.0; 
    // [골드 바] (왼쪽 상단)
    final goldSprite = Sprite(images.fromCache('user_gold_ui.png'));
    // 비율 유지하며 높이 자동 계산
    final goldSize = Vector2(goldUiWidth, goldUiWidth * (goldSprite.originalSize.y / goldSprite.originalSize.x));
    final goldBar = SpriteComponent(
      sprite: goldSprite,
      position: Vector2(10, 30),
      size: goldSize,
    );
    _goldText = TextComponent(
      text: '0',
      anchor: Anchor.centerRight, // ★ 우측 기준점
      position: Vector2(goldSize.x - 20, goldSize.y / 2), // ★ 오른쪽 끝에서 20만큼 안쪽, 수직 중앙
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    );
    goldBar.add(_goldText);
    add(goldBar);

    // [레벨 바] (오른쪽 상단)
    final levelSprite = Sprite(images.fromCache('user_sword_ui.png'));
    final levelSize = Vector2(swordUiWidth, swordUiWidth * (levelSprite.originalSize.y / levelSprite.originalSize.x));
    final levelBar = SpriteComponent(
      sprite: levelSprite,
      position: Vector2(size.x - 10, 30),
      anchor: Anchor.topRight, // 화면 오른쪽 기준 배치
      size: levelSize,
    );
    _levelText = TextComponent(
      text: 'Lv.1',
      anchor: Anchor.centerRight, // ★ 우측 기준점
      position: Vector2(levelSize.x - 20, levelSize.y / 2), // ★ 오른쪽 끝에서 20만큼 안쪽
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
    );
    levelBar.add(_levelText);
    add(levelBar);

    // 2. [Body] 중앙 검 이미지 영역 (나중에 SpriteComponent로 교체할 곳)
    // 지금은 위치 확인용 회색 박스
    add(RectangleComponent(
      position: Vector2(size.x / 2, size.y * 0.5), // 화면 정중앙
      size: Vector2(200, 400), // 검 이미지 크기
      anchor: Anchor.center,
      paint: Paint()..color = Colors.grey.withValues(alpha: 0.3),
    ));

    // [정보 패널] 버튼 위쪽 영역
    double infoY = size.y * 0.78; // 버튼보다 살짝 위
    // 반투명 배경 박스 (가독성용)
    add(RectangleComponent(
      position: Vector2(size.x / 2, infoY),
      size: Vector2(size.x * 0.9, 80),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.black.withValues(alpha: 0.5),
    ));
    // 1) 모인 골드 텍스트 (왼쪽)
    _accumulatedGoldText = TextBoxComponent(
      text: '모인 골드\n+0',
      position: Vector2(size.x * 0.25, infoY),
      anchor: Anchor.center,
      size: Vector2(200, 100), 
      align: Anchor.center, // 텍스트를 박스 중앙에 정렬
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      priority: 10,
    );
    add(_accumulatedGoldText);
    // 2) 강화 비용 텍스트 (오른쪽)
    _upgradeCostText = TextBoxComponent(
      text: '강화 비용\n-1000', // 초기값
      position: Vector2(size.x * 0.75, infoY),
      anchor: Anchor.center,
      size: Vector2(200, 100), 
      align: Anchor.center, // 텍스트를 박스 중앙에 정렬
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF6666),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      priority: 10,
    );
    add(_upgradeCostText);
    
    // 상태 메시지 (검 밑에 표시)
    _statusText = TextComponent(
      text: 'Connecting...',
      position: Vector2(size.x / 2, size.y * 0.75),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white54, fontSize: 16)),
    );
    add(_statusText);

    // [Footer] 하단 버튼 영역
    double btnY = size.y * 0.88;
    // 버튼 크기 (이미지 비율에 따라 조절 필요, 일단 가로 180으로 잡음)
    double btnWidth = 180.0;
    double btnHeight = 70.0; // 이미지 비율에 맞춰 자동 계산 로직 넣을 수도 있음
    // [수령] 버튼 (왼쪽)
    add(ImageButton(
      imageName: 'get_gold_btn_ui.png',
      position: Vector2(size.x * 0.25, btnY),
      size: Vector2(btnWidth, btnHeight),
      label: "",
      onTap: _collect,
    ));
    // [강화] 버튼 (오른쪽)
    add(ImageButton(
      imageName: 'upgrade_btn_ui.png',
      position: Vector2(size.x * 0.75, btnY),
      size: Vector2(btnWidth, btnHeight),
      label: "",
      onTap: _upgrade,
    ));

    _login();
  }

  // --- API 로직  ---
  Future<void> _login() async {
    try {
      final res = await _dio.post('$baseUrl/auth/login', data: {'deviceId': 'layout_fix_v1'});
      _userId = res.data['id'];

      // [수령 시간 초기화] 로그인 시점부터 골드 쌓기 시작
      _lastCollectionTime = DateTime.now(); 
      // [서버 데이터 반영] 서버에서 비용과 생산량을 받아온다고 가정
      // 만약 서버에 이 필드가 없다면 기본값이나 계산식을 넣어야 합니다.
      _cost = res.data['upgradeCost'] ?? 1000; 
      _profitPerSec = res.data['profitPerSec'] ?? (_level * 10); // 예시 로직

      updateUI(res.data['gold'], res.data['swordLevel'], "Ready to Forge");
    } catch (e) {
      _statusText.text = "Server Error";
    }
  }

  Future<void> _upgrade() async {
    if (_userId == 0) return;
    try {
      final res = await _dio.post('$baseUrl/game/upgrade', data: {'userId': _userId});
      bool success = res.data['success'];

      if (success) {
        // [성공 시 비용/생산량 증가]
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

      // [수령 후 시간 초기화] 다시 0부터 쌓이게 함
      _lastCollectionTime = DateTime.now();

      updateUI(res.data['currentGold'], _level, "+${res.data['earned']} Gold");
    } catch (e) {
      _statusText.text = "Too fast...";
    }
  }

  void updateUI(int gold, int level, String msg) {
    _gold = gold;
    _level = level;
    _goldText.text = '$_gold';
    // _goldText.text = 'GOLD: $_gold';
    _levelText.text = '$_level';
    _statusText.text = msg;
  }
}

// 이미지 기반 버튼 컴포넌트
// ignore: deprecated_member_use
class ImageButton extends PositionComponent with TapCallbacks, HasGameRef<ForgeGame> {
  final String imageName;
  final String label;
  final VoidCallback onTap;
  late SpriteComponent _sprite;

  ImageButton({
    required this.imageName,
    required Vector2 position,
    required Vector2 size,
    required this.label,
    required this.onTap,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // 이미지 로드
    _sprite = SpriteComponent(
      sprite: Sprite(gameRef.images.fromCache(imageName)),
      size: size,
    );
    add(_sprite);

    // 텍스트 추가 (이미지에 글씨가 없을 경우)
    if (label.isNotEmpty) {
      add(TextComponent(
        text: label,
        anchor: Anchor.center,
        position: size / 2, // 버튼 정중앙
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))] // 그림자 효과
          ),
        ),
      ));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTap();
    scale = Vector2.all(0.95); // 눌림 효과
  }

  @override
  void onTapUp(TapUpEvent event) => scale = Vector2.all(1.0);
  @override
  void onTapCancel(TapCancelEvent event) => scale = Vector2.all(1.0);
}
