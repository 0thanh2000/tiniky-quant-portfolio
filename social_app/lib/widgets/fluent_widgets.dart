import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../theme.dart';

// ============================================
// ⭐ FLUENT GLASS CARD — Mica blur effect
// ============================================
class FluentGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const FluentGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 30,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = FluentRadius.large,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark
            ? FluentColors.darkCard.withValues(alpha: 0.75)
            : FluentColors.lightCard.withValues(alpha: 0.85));

    final border = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.6));

    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: boxShadow ?? FluentShadows.raised(isDark: isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(FluentSpacing.lg),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ============================================
// ⭐ FLUENT CARD — Solid card
// ============================================
class FluentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool showBorder;
  final List<BoxShadow>? boxShadow;

  const FluentCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius = FluentRadius.large,
    this.onTap,
    this.showBorder = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (isDark ? FluentColors.darkCard : FluentColors.lightCard);
    final border = isDark
        ? FluentColors.darkBorder
        : FluentColors.lightBorder;

    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: border, width: 0.5) : null,
        boxShadow: boxShadow ?? FluentShadows.card(isDark: isDark),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(FluentSpacing.lg),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ============================================
// ⭐ FLUENT ICON BUTTON
// ============================================
class FluentIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool showBadge;
  final int badgeCount;

  const FluentIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size = 40,
    this.iconSize = 20,
    this.tooltip,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ??
        (isDark ? FluentColors.darkText : FluentColors.lightText);
    final bg = backgroundColor ?? Colors.transparent;

    Widget button = Material(
      color: bg,
      borderRadius: BorderRadius.circular(FluentRadius.medium),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(FluentRadius.medium),
        hoverColor: isDark
            ? FluentColors.darkHover
            : FluentColors.lightHover,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );

    if (showBadge && badgeCount > 0) {
      button = FluentBadge(
        count: badgeCount,
        child: button,
      );
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

// ============================================
// ⭐ FLUENT AVATAR
// ============================================
class FluentAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool showBorder;
  final IconData fallbackIcon;

  const FluentAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.showBorder = false,
    this.fallbackIcon = FluentIcons.person_24_filled,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: isDark
          ? FluentColors.darkCardAlt
          : FluentColors.lightInputBg,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Icon(
              fallbackIcon,
              size: size * 0.55,
              color: isDark
                  ? FluentColors.darkSubText
                  : FluentColors.lightSubText,
            )
          : null,
    );

    if (!showBorder) return avatar;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        gradient: AppGradients.fluentAccent,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark ? FluentColors.darkBg : Colors.white,
          shape: BoxShape.circle,
        ),
        child: avatar,
      ),
    );
  }
}

// ============================================
// ⭐ FLUENT BADGE
// ============================================
class FluentBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color color;
  final double fontSize;

  const FluentBadge({
    super.key,
    required this.child,
    required this.count,
    this.color = FluentColors.likeRed,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? FluentColors.darkBg : Colors.white,
                width: 1.5,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// ⭐ FLUENT PRIMARY BUTTON (gradient emerald)
// ============================================
class FluentPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final Gradient? gradient;

  const FluentPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.fullWidth = false,
    this.height = 48,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final button = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.fluentAccent,
        borderRadius: BorderRadius.circular(FluentRadius.medium),
        boxShadow: onPressed != null
            ? FluentShadows.floating(
                isDark: isDark, color: FluentColors.accent)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(FluentRadius.medium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FluentSpacing.xl),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: FluentSpacing.sm),
                ] else if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: FluentSpacing.sm),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

// ============================================
// ⭐ FLUENT SECONDARY BUTTON (outlined)
// ============================================
class FluentSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final double height;

  const FluentSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? FluentColors.darkBorder
        : FluentColors.lightBorder;
    final textColor = isDark
        ? FluentColors.darkText
        : FluentColors.lightText;

    final button = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FluentRadius.medium),
        border: Border.all(color: border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(FluentRadius.medium),
          hoverColor: isDark
              ? FluentColors.darkHover
              : FluentColors.lightHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FluentSpacing.xl),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(width: FluentSpacing.sm),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

// ============================================
// ⭐ FLUENT TEXT FIELD
// ============================================
class FluentTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  const FluentTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      style: TextStyle(
        color: isDark ? FluentColors.darkText : FluentColors.lightText,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ============================================
// ⭐ FLUENT SECTION TITLE
// ============================================
class FluentSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsets? padding;

  const FluentSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: FluentSpacing.lg,
            vertical: FluentSpacing.md,
          ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: FluentColors.accent,
              size: 20,
            ),
            const SizedBox(width: FluentSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? FluentColors.darkText
                    : FluentColors.lightText,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ============================================
// ⭐ FLUENT DIVIDER
// ============================================
class FluentDivider extends StatelessWidget {
  final double? indent;
  final double? endIndent;
  final double thickness;

  const FluentDivider({
    super.key,
    this.indent,
    this.endIndent,
    this.thickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: isDark
          ? FluentColors.darkDivider
          : FluentColors.lightDivider,
    );
  }
}

// ============================================
// ⭐ FLUENT EMPTY STATE
// ============================================
class FluentEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const FluentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FluentSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(FluentSpacing.xl),
              decoration: BoxDecoration(
                gradient: AppGradients.softGreen,
                shape: BoxShape.circle,
                boxShadow: FluentShadows
                    .glow(FluentColors.accent)
                    .map((s) => BoxShadow(
                          color: s.color.withValues(alpha: 0.15),
                          blurRadius: s.blurRadius,
                          spreadRadius: s.spreadRadius,
                        ))
                    .toList(),
              ),
              child: Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: FluentSpacing.xl),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? FluentColors.darkText
                    : FluentColors.lightText,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: FluentSpacing.sm),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? FluentColors.darkSubText
                      : FluentColors.lightSubText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: FluentSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}