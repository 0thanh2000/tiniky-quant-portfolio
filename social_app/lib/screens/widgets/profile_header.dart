import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import '../../utils/cloudinary_helper.dart';

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditCover;
  final VoidCallback onSettings;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.onEditAvatar,
    required this.onEditCover,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = profile?['cover_url'];
    final avatarUrl = profile?['avatar_url'];

    final screenWidth = MediaQuery.of(context).size.width;
    final coverHeight = screenWidth * 0.56;
    const avatarRadius = 56.0;
    const avatarBorder = 7.0;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: coverHeight + avatarRadius + avatarBorder,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ===== COVER PHOTO =====
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ⭐ COVER với Cloudinary transformation
                  if (coverUrl != null && coverUrl.toString().isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: CloudinaryHelper.coverPhoto(coverUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppGradients.primaryGradient,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppGradients.primaryGradient,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppGradients.primaryGradient,
                      ),
                    ),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0, 0.4, 1],
                        ),
                      ),
                    ),
                  ),

                  // Settings
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onSettings,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Camera
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onEditCover,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== AVATAR =====
            Positioned(
              top: coverHeight - avatarRadius - avatarBorder,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onEditAvatar,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkBg : Colors.white,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppGradients.primaryGradient,
                          ),
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: AppColors.gradStart,
                            // ⭐ AVATAR với Cloudinary transformation
                            backgroundImage: avatarUrl != null &&
                                    avatarUrl.toString().isNotEmpty
                                ? CachedNetworkImageProvider(
                                    CloudinaryHelper.avatarLarge(avatarUrl))
                                : null,
                            child: avatarUrl == null ||
                                    avatarUrl.toString().isEmpty
                                ? const Icon(Icons.person,
                                    size: 56, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gradStart,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isDark ? AppColors.darkBg : Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}