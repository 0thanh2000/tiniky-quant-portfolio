import 'package:flutter/material.dart';
import 'create_post_screen.dart';
class EditPostScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  const EditPostScreen({super.key, required this.post});
  @override Widget build(BuildContext context) => CreatePostScreen(post: post);
}
