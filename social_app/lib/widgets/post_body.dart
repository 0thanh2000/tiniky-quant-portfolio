import 'package:flutter/material.dart';
import '../models/post_media.dart';
import '../screens/widgets/hashtag_text.dart';
import 'media_gallery.dart';
class PostBody extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool expanded;
  final VoidCallback? onOpen;
  const PostBody({super.key, required this.post, this.expanded = false, this.onOpen});
  @override Widget build(BuildContext context) {
    final content = post['content']?.toString() ?? '';
    final media = PostMedia.fromPost(post);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (content.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: expanded ? HashtagText(text: content, style: const TextStyle(fontSize: 15, height: 1.45))
          : LayoutBuilder(builder: (context, constraints) {
            final style = DefaultTextStyle.of(context).style.copyWith(fontSize: 15, height: 1.45);
            final painter = TextPainter(text: TextSpan(text: content, style: style), maxLines: 5,
              textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout(maxWidth: constraints.maxWidth);
            final overflow = painter.didExceedMaxLines;
            painter.dispose();
            return InkWell(onTap: onOpen, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(content, maxLines: 5, overflow: TextOverflow.ellipsis, style: style),
              if (overflow) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Xem đầy đủ',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))),
            ]));
          })),
      if (media.isNotEmpty) MediaGallery(items: media),
    ]);
  }
}
