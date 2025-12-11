// features/home/presentation/widgets/search_result_highlighter.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget that highlights search query in text
class SearchResultHighlighter extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final Color? highlightColor;

  const SearchResultHighlighter({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty || text.isEmpty) {
      return Text(text, style: style);
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final defaultStyle = style ?? GoogleFonts.inter();
    final highlightStyle = defaultStyle.copyWith(
      backgroundColor: highlightColor ?? Theme.of(context).colorScheme.primary.withOpacity(0.2),
      fontWeight: FontWeight.w700,
    );

    if (!textLower.contains(queryLower)) {
      return Text(text, style: defaultStyle);
    }

    final spans = <TextSpan>[];
    int start = 0;
    final queryLength = query.length;

    while (start < text.length) {
      final index = textLower.indexOf(queryLower, start);
      if (index == -1) {
        // Add remaining text
        spans.add(TextSpan(
          text: text.substring(start),
          style: defaultStyle,
        ));
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: defaultStyle,
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + queryLength),
        style: highlightStyle,
      ));

      start = index + queryLength;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

