import 'dart:math';
import 'dart:ui' as ui;

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:material_ui/material_ui.dart';

abstract final class DmUtils {
  static const maxRasterizeSize = 8192.0;

  static double devicePixelRatio = 1;
  static final Paint _selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.green;

  static final Paint _emotePaint = Paint()
    ..filterQuality = FilterQuality.medium;

  static void updateSelfSendPaint(double strokeWidth) {
    _selfSendPaint.strokeWidth = strokeWidth;
  }

  static String? fontFamily;

  static ui.Paragraph _buildTextParagraph({
    required String text,
    required Color color,
    required double fontSize,
    required int fontWeight,
    int? count,
    Paint? foreground,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      fontFamily: fontFamily,
      maxLines: 1,
    ));

    if (count != null) {
      builder
        ..pushStyle(ui.TextStyle(
          color: foreground == null ? color : null,
          foreground: foreground,
          fontSize: fontSize * 0.6,
        ))
        ..addText('($count)')
        ..pop();
    }

    builder
      ..pushStyle(ui.TextStyle(
        color: foreground == null ? color : null,
        foreground: foreground,
        fontSize: fontSize,
      ))
      ..addText(text);

    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  static ui.Paragraph generateParagraph({
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
  }) {
    return _buildTextParagraph(
      text: content.text,
      color: content.color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      count: content.count,
    );
  }

  static (ui.Image, double, double) recordEmoteImage({
    required DanmakuContentItem content,
    required double fontSize,
    required double strokeWidth,
  }) {
    final emote = content.emoteImage!;
    final targetH = fontSize * 1.85;
    final ratio = emote.height > 0 ? emote.width / emote.height : 1.0;
    final targetW = targetH * ratio;
    double w = targetW + strokeWidth + (content.selfSend ? 4.0 : 0.0);
    double h = targetH + strokeWidth;

    final offset = Offset(
      (strokeWidth / 2.0) + (content.selfSend ? 2.0 : 0.0),
      strokeWidth / 2.0,
    );

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    if (devicePixelRatio != 1) {
      canvas.scale(devicePixelRatio);
    }

    canvas.drawImageRect(
      emote,
      Rect.fromLTWH(0, 0, emote.width.toDouble(), emote.height.toDouble()),
      Rect.fromLTWH(offset.dx, offset.dy, targetW, targetH),
      _emotePaint,
    );

    if (content.selfSend) {
      canvas.drawRect(Rect.fromLTRB(0, 0, w, h), _selfSendPaint);
    }

    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (w * devicePixelRatio).ceil().clamp(1, maxRasterizeSize.toInt()),
      (h * devicePixelRatio).ceil().clamp(1, maxRasterizeSize.toInt()),
    );
    pic.dispose();
    return (img, w, h);
  }

  static (ui.Image, double, double) recordMixedDanmakuImage({
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
  }) {
    final emotes = content.emotes!;
    final emoteSize = fontSize * 1.25;
    final regExp = RegExp(emotes.keys.map(RegExp.escape).join('|'));

    final List<(String?, ui.Image?)> segments = [];
    var isFirstSegment = true;

    content.text.splitMapJoin(
      regExp,
      onMatch: (match) {
        final key = match[0]!;
        final img = emotes[key];
        if (img != null) {
          segments.add((null, img));
        } else {
          segments.add((key, null));
        }
        return '';
      },
      onNonMatch: (nonMatch) {
        if (nonMatch.isNotEmpty) {
          segments.add((nonMatch, null));
        }
        return '';
      },
    );

    double contentW = 0.0;
    double contentH = emoteSize;
    final List<(ui.Paragraph?, ui.Image?, double, double)> laidOut = [];

    for (final (text, emote) in segments) {
      if (emote != null) {
        final ratio = emote.height > 0 ? emote.width / emote.height : 1.0;
        final ew = emoteSize * ratio;
        laidOut.add((null, emote, ew, emoteSize));
        contentW += ew + 2.0;
      } else if (text != null && text.isNotEmpty) {
        final p = _buildTextParagraph(
          text: text,
          color: content.color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          count: isFirstSegment ? content.count : null,
        );
        isFirstSegment = false;
        final pw = p.maxIntrinsicWidth;
        final ph = p.height;
        if (ph > contentH) contentH = ph;
        laidOut.add((p, null, pw, ph));
        contentW += pw;
      }
    }

    if (laidOut.isEmpty) {
      final p = generateParagraph(
        content: content,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
      final img = recordDanmakuImage(
        contentParagraph: p,
        content: content,
        fontSize: fontSize,
        fontWeight: fontWeight,
        strokeWidth: strokeWidth,
      );
      final w = p.maxIntrinsicWidth + strokeWidth + (content.selfSend ? 4.0 : 0.0);
      final h = p.height + strokeWidth;
      p.dispose();
      return (img, w, h);
    }

    double w = contentW + strokeWidth + (content.selfSend ? 4.0 : 0.0);
    double h = contentH + strokeWidth;
    final baseOffsetX = (strokeWidth / 2.0) + (content.selfSend ? 2.0 : 0.0);
    final baseOffsetY = strokeWidth / 2.0;

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    if (devicePixelRatio != 1) {
      canvas.scale(devicePixelRatio);
    }

    double cursorX = baseOffsetX;
    var firstStroke = true;

    for (var idx = 0; idx < laidOut.length; idx++) {
      final (p, emote, segW, segH) = laidOut[idx];
      final yOffset = baseOffsetY + (contentH - segH) / 2.0;
      if (emote != null) {
        canvas.drawImageRect(
          emote,
          Rect.fromLTWH(0, 0, emote.width.toDouble(), emote.height.toDouble()),
          Rect.fromLTWH(cursorX, yOffset, segW, segH),
          _emotePaint,
        );
        cursorX += segW + 2.0;
      } else if (p != null) {
        final rawText = segments[idx].$1!;
        if (strokeWidth != 0) {
          final strokePaint = Paint()
            ..shader = content.isColorful
                ? const LinearGradient(
                    colors: [Color(0xFFF2509E), Color(0xFF308BCD)])
                    .createShader(Rect.fromLTWH(0, 0, w, h))
                : null
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth;
          if (!content.isColorful) {
            strokePaint.color = Colors.black;
          }
          final strokeP = _buildTextParagraph(
            text: rawText,
            color: content.color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            count: firstStroke ? content.count : null,
            foreground: strokePaint,
          );
          firstStroke = false;
          canvas.drawParagraph(strokeP, Offset(cursorX, yOffset));
          strokeP.dispose();
        }
        canvas.drawParagraph(p, Offset(cursorX, yOffset));
        p.dispose();
        cursorX += segW;
      }
    }

    if (content.selfSend) {
      canvas.drawRect(Rect.fromLTRB(0, 0, w, h), _selfSendPaint);
    }

    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (w * devicePixelRatio).ceil().clamp(1, maxRasterizeSize.toInt()),
      (h * devicePixelRatio).ceil().clamp(1, maxRasterizeSize.toInt()),
    );
    pic.dispose();
    return (img, w, h);
  }

  static ui.Image recordDanmakuImage({
    required ui.Paragraph contentParagraph,
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
  }) {
    double w = contentParagraph.maxIntrinsicWidth + strokeWidth;
    double h = contentParagraph.height + strokeWidth;

    final offset = Offset(
      (strokeWidth / 2.0) + (content.selfSend ? 2.0 : 0.0),
      strokeWidth / 2.0,
    );

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    if (devicePixelRatio != 1) {
      canvas.scale(devicePixelRatio);
    }

    if (strokeWidth != 0) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontWeight: FontWeight.values[fontWeight],
        textDirection: TextDirection.ltr,
        fontFamily: fontFamily,
        maxLines: 1,
      ));
      final Paint strokePaint = Paint()
        ..shader = content.isColorful
            ? const LinearGradient(
                colors: [Color(0xFFF2509E), Color(0xFF308BCD)])
                .createShader(Rect.fromLTWH(0, 0, w, h))
            : null
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      if (!content.isColorful) {
        strokePaint.color = Colors.black;
      }

      if (content.count case final count?) {
        builder
          ..pushStyle(ui.TextStyle(
            fontSize: fontSize * 0.6,
            foreground: strokePaint,
          ))
          ..addText('($count)')
          ..pop();
      }

      builder
        ..pushStyle(ui.TextStyle(fontSize: fontSize, foreground: strokePaint))
        ..addText(content.text);

      final strokeParagraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));

      canvas.drawParagraph(strokeParagraph, offset);
      strokeParagraph.dispose();
    }

    canvas.drawParagraph(contentParagraph, offset);

    if (content.selfSend) {
      w += 4;
      canvas.drawRect(Rect.fromLTRB(0, 0, w, h), _selfSendPaint);
    }

    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (w * devicePixelRatio).ceil(),
      (h * devicePixelRatio).ceil(),
    );
    pic.dispose();
    return img;
  }

  static ui.Image recordSpecialDanmakuImg({
    required SpecialDanmakuContentItem content,
    required int fontWeight,
    required double strokeWidth,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      fontSize: content.fontSize,
      fontFamily: fontFamily,
    ))
      ..pushStyle(ui.TextStyle(
        color: content.color,
        fontSize: content.fontSize,
        shadows: content.hasStroke
            ? [Shadow(color: Colors.black, blurRadius: strokeWidth)]
            : null,
      ))
      ..addText(content.text);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final strokeOffset = strokeWidth / 2;
    final totalWidth = paragraph.maxIntrinsicWidth + strokeWidth;
    final totalHeight = paragraph.height + strokeWidth;

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);

    Rect rect;

    if (content.rotateZ != 0 || content.matrix != null) {
      rect = _calculateRotatedBounds(
        totalWidth,
        totalHeight,
        content.rotateZ,
        content.matrix,
      );

      if (devicePixelRatio != 1) {
        canvas.scale(devicePixelRatio);
      }
      canvas.translate(strokeOffset - rect.left, strokeOffset - rect.top);

      if (content.matrix case final matrix?) {
        canvas.transform(matrix.storage);
      } else {
        canvas.rotate(content.rotateZ);
      }
      canvas.drawParagraph(paragraph, Offset.zero);
    } else {
      rect = Rect.fromLTRB(0, 0, totalWidth, totalHeight);

      if (devicePixelRatio != 1) {
        canvas.scale(devicePixelRatio);
      }
      canvas.drawParagraph(paragraph, Offset(strokeOffset, strokeOffset));
    }
    paragraph.dispose();

    double width = rect.width * devicePixelRatio;
    double height = rect.height * devicePixelRatio;
    if (width > maxRasterizeSize || height > maxRasterizeSize) {
      final scaledMaxSize = maxRasterizeSize / devicePixelRatio;
      final left = rect.left;
      final top = rect.top;
      double right = rect.right;
      double bottom = rect.bottom;

      if (width > maxRasterizeSize) {
        right = left + scaledMaxSize;
        width = maxRasterizeSize;
      }

      if (height > maxRasterizeSize) {
        bottom = top + scaledMaxSize;
        height = maxRasterizeSize;
      }

      rect = Rect.fromLTRB(left, top, right, bottom);
    }

    content.rect = rect;

    final pic = rec.endRecording();
    final img = pic.toImageSync(width.ceil(), height.ceil());
    pic.dispose();

    return img;
  }

  static Rect _calculateRotatedBounds(
    double w,
    double h,
    double rotateZ,
    Matrix4? matrix,
  ) {
    final double cosZ;
    final double cosY;
    final double sinZ;
    if (matrix == null) {
      cosZ = cos(rotateZ);
      sinZ = sin(rotateZ);
      cosY = 1;
    } else {
      cosZ = matrix[5];
      sinZ = matrix[1];
      cosY = matrix[10];
    }

    final wx = w * cosZ * cosY;
    final wy = w * sinZ;
    final hx = -h * sinZ * cosY;
    final hy = h * cosZ;

    final minX = _min4(0.0, wx, hx, wx + hx);
    final maxX = _max4(0.0, wx, hx, wx + hx);
    final minY = _min4(0.0, wy, hy, wy + hy);
    final maxY = _max4(0.0, wy, hy, wy + hy);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @pragma("vm:prefer-inline")
  static double _min4(double a, double b, double c, double d) {
    final ab = a < b ? a : b;
    final cd = c < d ? c : d;
    return ab < cd ? ab : cd;
  }

  @pragma("vm:prefer-inline")
  static double _max4(double a, double b, double c, double d) {
    final ab = a > b ? a : b;
    final cd = c > d ? c : d;
    return ab > cd ? ab : cd;
  }
}