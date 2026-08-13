import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Renders the coach's reply using the exact same restricted markdown
/// subset `frontend/src/components/MarkdownMessage.tsx` allows — bold,
/// bullet/numbered lists, paragraphs, headings — as a small dependency-free
/// parser rather than pulling in a general-purpose markdown package for a
/// handful of tags.
class MarkdownMessage extends StatelessWidget {
  final String content;

  /// Defaults to the theme's `ink` token (was previously a hardcoded
  /// `#F5F5F5`, which duplicated the token and never adapted to light mode).
  final Color? textColor;

  const MarkdownMessage({super.key, required this.content, this.textColor});

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? context.colors.ink;
    final lines = content.split('\n');
    final widgets = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        i++;
        continue;
      }
      if (trimmed.startsWith('#')) {
        final headingMatch = RegExp(r'^(#+)').firstMatch(trimmed)!;
        final level = headingMatch.group(1)!.length;
        widgets.add(_richText(trimmed.replaceFirst(RegExp(r'^#+\s*'), ''), color, bold: true, headingLevel: level));
      } else if (RegExp(r'^[-*]\s+').hasMatch(trimmed)) {
        while (i < lines.length && RegExp(r'^[-*]\s+').hasMatch(lines[i].trim())) {
          widgets.add(_bulletLine(lines[i].trim().replaceFirst(RegExp(r'^[-*]\s+'), ''), color));
          i++;
        }
        continue;
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        while (i < lines.length && RegExp(r'^\d+\.\s+').hasMatch(lines[i].trim())) {
          final match = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(lines[i].trim())!;
          widgets.add(_bulletLine(match.group(2)!, color, prefix: '${match.group(1)}.'));
          i++;
        }
        continue;
      } else {
        widgets.add(_richText(trimmed, color));
      }
      i++;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: widgets);
  }

  Widget _bulletLine(String text, Color color, {String prefix = '•'}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 18, child: Text(prefix, style: TextStyle(color: color, fontSize: 13))),
          Expanded(child: _richText(text, color)),
        ],
      ),
    );
  }

  Widget _richText(String text, Color color, {bool bold = false, int? headingLevel}) {
    final spans = <TextSpan>[];
    final parts = text.split(RegExp(r'(\*\*.*?\*\*)'));
    for (final part in parts) {
      if (part.startsWith('**') && part.endsWith('**') && part.length > 3) {
        spans.add(TextSpan(
          text: part.substring(2, part.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (part.isNotEmpty) {
        spans.add(TextSpan(text: part));
      }
    }
    // h1 > h2 > h3+ get modestly distinct sizes rather than all collapsing
    // to the same bold body size.
    final fontSize = switch (headingLevel) {
      1 => 16.0,
      2 => 15.0,
      3 => 14.0,
      _ => 13.0,
    };
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.4,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        ),
        children: spans,
      ),
    );
  }
}
