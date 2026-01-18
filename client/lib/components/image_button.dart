import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../main.dart'; 

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
    _sprite = SpriteComponent(
      sprite: Sprite(gameRef.images.fromCache(imageName)),
      size: size,
    );
    add(_sprite);

    if (label.isNotEmpty) {
      add(TextComponent(
        text: label,
        anchor: Anchor.center,
        position: size / 2,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]
          ),
        ),
      ));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTap();
    scale = Vector2.all(0.95);
  }

  @override
  void onTapUp(TapUpEvent event) => scale = Vector2.all(1.0);
  
  @override
  void onTapCancel(TapCancelEvent event) => scale = Vector2.all(1.0);
}