import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';           // Lùi 2 cấp: widgets → screens → lib
import '../hashtag_screen.dart';     // Cùng cấp screens

class HashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseStyle = style ??
        TextStyle(
          fontSize: 15,
          height: 1.4,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        );

    final spans = _buildSpans(context, baseStyle);

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: spans),
    );
  }

  List<TextSpan> _buildSpans(BuildContext context, TextStyle baseStyle) {
    final regExp = RegExp(r'#[A-Za-z0-9_\u00C0-\u1EF9]+');
    final matches = regExp.allMatches(text);

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Text trước hashtag
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      // Hashtag
      final hashtag = match.group(0)!;
      spans.add(TextSpan(
        text: hashtag,
        style: baseStyle.copyWith(
          color: AppColors.gradStart,
          fontWeight: FontWeight.bold,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HashtagScreen(hashtag: hashtag),
              ),
            );
          },
      ));

      lastIndex = match.end;
    }

    // Text cuối cùng
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
