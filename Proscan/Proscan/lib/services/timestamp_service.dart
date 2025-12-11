import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';

/// Service responsible for embedding a formatted timestamp onto an image.
class TimestampService {
  static const String _timestampFormat = 'EEEE, MMMM dd, yyyy – HH:mm:ss';

  /// Adds a timestamp overlay to the provided [bytes] representing an encoded image.
  ///
  /// The timestamp is rendered in the bottom‑right corner in the format:
  /// `EEEE, MMMM dd, yyyy – HH:mm:ss`.
  Future<Uint8List> addTimestampToImage(Uint8List bytes) async {
    // Decode image using dart:ui so we can draw with Canvas.
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final width = image.width.toDouble();
    final height = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw original image first.
    final paint = ui.Paint();
    canvas.drawImage(image, ui.Offset.zero, paint);

    // Build timestamp text.
    final now = DateTime.now();
    final formatted = DateFormat(_timestampFormat).format(now);

    // --- Layout parameters -------------------------------------------------
    // Margin from the image edges (bottom/right) in logical pixels.
    final minDimension = width < height ? width : height;
    final margin = (minDimension * 0.04).clamp(24.0, 32.0); // 24–32 px
    final innerPadding =
        margin * 0.5; // padding inside background box (12–16 px)

    // Font size scaled by image width but kept within 32–40 px for readability.
    final baseFontSize =
        width * 0.018; // tuned for large images (e.g., 3k px wide)
    final fontSize = baseFontSize.clamp(32.0, 40.0);

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontWeight: ui.FontWeight.w700, // bold, modern look
      fontSize: fontSize,
    );

    final textStyle = ui.TextStyle(
      color: const ui.Color(0xFFFFFFFF), // white text
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(formatted);

    var paragraph = builder.build();

    // First layout pass to obtain intrinsic width for a single line.
    paragraph.layout(ui.ParagraphConstraints(width: width));
    final intrinsicWidth = paragraph.maxIntrinsicWidth;

    // Maximum width available for the text inside the margins and padding.
    final maxTextWidth = width - (2 * margin) - (2 * innerPadding);
    if (maxTextWidth <= 0) {
      // Image is too small to safely draw the overlay; return original bytes.
      final picture = recorder.endRecording();
      final stampedImage = await picture.toImage(image.width, image.height);
      final byteData = await stampedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData!.buffer.asUint8List();
    }

    // Use intrinsic width when possible; otherwise wrap text to fit.
    final targetTextWidth = intrinsicWidth <= maxTextWidth
        ? intrinsicWidth
        : maxTextWidth;

    // Second layout pass with the final target width.
    paragraph.layout(ui.ParagraphConstraints(width: targetTextWidth));

    final textWidth = targetTextWidth;
    final textHeight = paragraph.height;

    // Background box dimensions (sized dynamically based on text size).
    final bgRight = width - margin;
    final bgBottom = height - margin;
    final bgLeft = bgRight - textWidth - (2 * innerPadding);
    final bgTop = bgBottom - textHeight - (2 * innerPadding);

    // Safety: if the box would go out of bounds vertically, clamp to top margin.
    double safeBgTop = bgTop;
    double safeBgBottom = bgBottom;
    final minTop = margin;
    if (safeBgTop < minTop) {
      final boxHeight = textHeight + (2 * innerPadding);
      safeBgTop = minTop;
      safeBgBottom = (safeBgTop + boxHeight).clamp(minTop + boxHeight, height);
    }

    final backgroundRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTRB(bgLeft, safeBgTop, bgRight, safeBgBottom),
      ui.Radius.circular(margin * 0.6), // slightly rounded corners
    );

    // Semi‑transparent black background box (60–70% opacity).
    final backgroundPaint = ui.Paint()
      ..color = const ui.Color(0xB3000000); // ~70% opacity black

    canvas.drawRRect(backgroundRect, backgroundPaint);

    // Draw timestamp text on top of the background.
    final textOffset = ui.Offset(
      bgLeft + innerPadding,
      safeBgTop + innerPadding,
    );
    canvas.drawParagraph(paragraph, textOffset);

    // Finalize image.
    final picture = recorder.endRecording();
    final stampedImage = await picture.toImage(image.width, image.height);
    final byteData = await stampedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }
}
