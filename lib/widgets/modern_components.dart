import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:glassmorphism/glassmorphism.dart';

// === COMPOSANTS UI MODERNES ===

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool animate;

  const ModernCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      );
    }

    if (animate) {
      card = card.animate().fadeIn(duration: 300.ms).slideY(
        begin: 0.3,
        duration: 300.ms,
        curve: Curves.easeOutCubic,
      );
    }

    return card;
  }
}

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.2,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: null,
      borderRadius: 20,
      blur: blur,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.5),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;

    Widget button = Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isOutlined ? null : LinearGradient(
          colors: [
            buttonColor,
            buttonColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: isOutlined ? Border.all(color: buttonColor, width: 2) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOutlined ? buttonColor : Colors.white,
                      ),
                    ),
                  )
                else if (icon != null)
                  Icon(
                    icon,
                    color: isOutlined ? buttonColor : Colors.white,
                    size: 20,
                  ),
                if ((icon != null || isLoading) && text.isNotEmpty)
                  const SizedBox(width: 12),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: TextStyle(
                      color: isOutlined ? buttonColor : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return button.animate().scale(
      duration: 150.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class ModernTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;

  const ModernTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(
      begin: 0.1,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class AnimatedListTile extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int index;

  const AnimatedListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: ListTile(
            leading: leading,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
        ),
      ),
    );
  }
}

class ModernCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final Color? color;

  const ModernCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final checkboxColor = color ?? Theme.of(context).colorScheme.primary;

    Widget checkbox = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value ? checkboxColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? checkboxColor : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: value
          ? const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            )
          : null,
    );

    if (onChanged != null) {
      checkbox = InkWell(
        onTap: () => onChanged!(!value),
        borderRadius: BorderRadius.circular(6),
        child: checkbox,
      );
    }

    if (label != null) {
      return Row(
        children: [
          checkbox,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label!,
              style: TextStyle(
                color: value ? Colors.grey.shade600 : null,
                decoration: value ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      );
    }

    return checkbox;
  }
}

class ModernFloatingActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  const ModernFloatingActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            buttonColor,
            buttonColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    ).animate().scale(
      duration: 200.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;

  const ModernAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      leading: leading,
      actions: actions,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface.withOpacity(0.9),
              Theme.of(context).colorScheme.surface.withOpacity(0.7),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ModernBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showDragHandle;

  const ModernBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
          Flexible(child: child),
        ],
      ),
    );
  }
} 