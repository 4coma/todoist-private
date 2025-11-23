import 'package:flutter/material.dart';
import 'tokens.dart';

// Pill-style segmented filter chip
class DSSegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const DSSegmentChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? DSColor.pillSelected : DSColor.pillBg;
    final fg = selected ? Colors.white : DSColor.body;
    return InkWell(
      borderRadius: DSRadius.pill,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: DSRadius.pill,
        ),
        child: Text(
          label,
          style: DSTypo.body.copyWith(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// Date pill used in the horizontal date carousel
class DSDatePill extends StatelessWidget {
  final String month;
  final String day;
  final String week;
  final bool selected;

  const DSDatePill({
    super.key,
    required this.month,
    required this.day,
    required this.week,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? DSColor.pillSelected : Colors.white;
    final fg = selected ? Colors.white : DSColor.heading;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DSRadius.round,
        boxShadow: DSShadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(month, style: DSTypo.caption.copyWith(color: fg.withOpacity(0.9))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.2) : DSColor.surfaceSoft,
              borderRadius: DSRadius.pill,
            ),
            child: Text(
              day,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(week, style: DSTypo.caption.copyWith(color: fg.withOpacity(0.9))),
        ],
      ),
    );
  }
}

// Small status tag (Done / In Progress / To-do)
class DSStatusTag extends StatelessWidget {
  final String label;
  final Color color;

  const DSStatusTag.done({super.key})
      : label = 'Done',
        color = DSColor.success;

  const DSStatusTag.inProgress({super.key})
      : label = 'In Progress',
        color = DSColor.warning;

  const DSStatusTag.todo({super.key})
      : label = 'To-do',
        color = DSColor.info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: DSRadius.pill,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// Task card inspired by the screenshot
class DSTaskCard extends StatelessWidget {
  final IconData categoryIcon;
  final Color categoryColor;
  final String category;
  final String title;
  final String time;
  final Widget status;
  final bool isCompleted;

  const DSTaskCard({
    super.key,
    required this.categoryIcon,
    required this.categoryColor,
    required this.category,
    required this.title,
    required this.time,
    required this.status,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surfaceColor = DSColor.getSurface(brightness);
    final headingColor = DSColor.getHeading(brightness);
    final bodyColor = DSColor.getBody(brightness);
    final mutedColor = DSColor.getMuted(brightness);
    
    return Opacity(
      opacity: isCompleted ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: DSRadius.round,
          boxShadow: isCompleted 
              ? [] // Pas d'ombre pour les tâches terminées
              : brightness == Brightness.dark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : DSShadow.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(isCompleted ? 0.08 : 0.15),
                borderRadius: DSRadius.round,
              ),
              child: Icon(
                categoryIcon, 
                color: isCompleted ? categoryColor.withOpacity(0.5) : categoryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category, 
                    style: DSTypo.caption.copyWith(
                      color: isCompleted ? mutedColor : mutedColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title, 
                    style: DSTypo.h2.copyWith(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? mutedColor : headingColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule, 
                        size: 16, 
                        color: isCompleted ? mutedColor.withOpacity(0.6) : mutedColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time, 
                        style: DSTypo.body.copyWith(
                          color: isCompleted ? mutedColor.withOpacity(0.6) : mutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            status,
          ],
        ),
      ),
    );
  }
}

// Rounded background + top bar used by the demo screen
class DSBackdrop extends StatelessWidget {
  final Widget child;
  const DSBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradient = DSColor.getBackdropGradient(brightness);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: SafeArea(
        child: child,
      ),
    );
  }
}

