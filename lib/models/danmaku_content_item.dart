import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum DanmakuItemType {
  scroll,
  top,
  bottom,
  special,
}

class DanmakuContentItem<T> {
  /// 弹幕文本
  final String text;

  /// 弹幕颜色
  Color color;

  /// 弹幕类型
  final DanmakuItemType type;

  /// 是否为自己发送
  final bool selfSend;

  /// 是否为会员弹幕
  final bool isColorful;

  /// 弹幕数量
  final int? count;

  final T? extra;

  /// 整条表情图片（如直播间大表情）
  final ui.Image? emoteImage;

  /// 行内文本嵌入表情映射
  final Map<String, ui.Image>? emotes;

  DanmakuContentItem(
    this.text, {
    this.color = Colors.white,
    this.type = DanmakuItemType.scroll,
    this.selfSend = false,
    this.isColorful = false,
    this.count,
    this.extra,
    this.emoteImage,
    this.emotes,
  });
}

class SpecialDanmakuContentItem<T> extends DanmakuContentItem<T> {
  final int duration;
  final double fontSize;
  final bool hasStroke;
  final Tween<double>? alphaTween;
  final Tween<double>? translateXTween;
  final Tween<double>? translateYTween;
  final int translationDuration;
  final int translationStartDelay;
  final double rotateZ;
  final Matrix4? matrix;
  final Curve easingType;
  late Rect rect;

  SpecialDanmakuContentItem(
    super.text, {
    required this.duration,
    required super.color,
    required this.fontSize,
    this.hasStroke = false,
    this.translateXTween,
    this.translateYTween,
    this.alphaTween,
    this.matrix,
    this.easingType = Curves.linear,
    this.translationDuration = 0,
    this.translationStartDelay = 0,
    this.rotateZ = 0,
    super.extra,
  }) : super(type: DanmakuItemType.special);
}