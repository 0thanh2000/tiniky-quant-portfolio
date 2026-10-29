import 'package:flutter/material.dart';
import '../../theme.dart';

class ProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;
  final int postCount;
  final int videoCount;
  final int photoCount;

  const ProfileTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.postCount,
    required this.videoCount,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      {'label': 'Bài viết', 'count': postCount},
      {'label': 'Ảnh', 'count': photoCount},
      {'label': 'Video', 'count': videoCount},
      {'label': 'Giới thiệu', 'count': null},
      {'label': 'Bạn bè', 'count': null},
    ];

    return Container(
      color: isDark ? AppColors.darkCard : Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = i == selectedIndex;
            // Keep the minimum width, but let labels and counts grow together.
            return IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 104),
                child: GestureDetector(
                  onTap: () => onTabChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tabs[i]['label'] as String,
                              style: TextStyle(
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isActive
                                    ? AppColors.gradStart
                                    : (isDark
                                        ? AppColors.darkSubText
                                        : AppColors.lightSubText),
                                fontSize: 14,
                              ),
                            ),
                            if (tabs[i]['count'] != null) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.gradStart
                                      : (isDark
                                          ? AppColors.darkBg
                                          : Colors.grey[200]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${tabs[i]['count']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkSubText
                                            : AppColors.lightSubText),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? AppGradients.primaryGradient
                              : null,
                          color: isActive ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
