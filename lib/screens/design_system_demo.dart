import 'package:flutter/material.dart';
import '../design_system/tokens.dart';
import '../design_system/widgets.dart';

/// Demo screen that showcases the Design System tokens and widgets
/// while mimicking the provided UI for today's tasks.
class DesignSystemDemoScreen extends StatefulWidget {
  const DesignSystemDemoScreen({super.key});

  @override
  State<DesignSystemDemoScreen> createState() => _DesignSystemDemoScreenState();
}

class _DesignSystemDemoScreenState extends State<DesignSystemDemoScreen> {
  int selectedSegment = 0; // 0: All, 1: To do, 2: In Progress, 3: Completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DSBackdrop(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final headingColor = DSColor.getHeading(Theme.of(context).brightness);
                      return Icon(Icons.reply, color: headingColor);
                    },
                  ),
                  Builder(
                    builder: (context) => Text("Today's Tasks", style: DSTypo.h1Of(context)),
                  ),
                  Builder(
                    builder: (context) {
                      final headingColor = DSColor.getHeading(Theme.of(context).brightness);
                      return Icon(Icons.notifications_none, color: headingColor);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Horizontal date pills
            SizedBox(
              height: 108,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: const [
                  _DateItem('May', '23', 'Fri'),
                  SizedBox(width: 10),
                  _DateItem('May', '24', 'Sat'),
                  SizedBox(width: 10),
                  _DateItem('May', '25', 'Sun', selected: true),
                  SizedBox(width: 10),
                  _DateItem('May', '26', 'Mon'),
                  SizedBox(width: 10),
                  _DateItem('May', '27', 'Tue'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Segments
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  DSSegmentChip(
                    label: 'All',
                    selected: selectedSegment == 0,
                    onTap: () => setState(() => selectedSegment = 0),
                  ),
                  const SizedBox(width: 10),
                  DSSegmentChip(
                    label: 'To do',
                    selected: selectedSegment == 1,
                    onTap: () => setState(() => selectedSegment = 1),
                  ),
                  const SizedBox(width: 10),
                  DSSegmentChip(
                    label: 'In Progress',
                    selected: selectedSegment == 2,
                    onTap: () => setState(() => selectedSegment = 2),
                  ),
                  const SizedBox(width: 10),
                  DSSegmentChip(
                    label: 'Completed',
                    selected: selectedSegment == 3,
                    onTap: () => setState(() => selectedSegment = 3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Task list mimic
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                children: [
                  DSTaskCard(
                    categoryIcon: Icons.shopping_bag_outlined,
                    categoryColor: const Color(0xFFFB6B9D),
                    category: 'Grocery shopping app design',
                    title: 'Market Research',
                    time: '10:00 AM',
                    isCompleted: true,
                    status: const DSStatusTag.done(),
                  ),
                  DSTaskCard(
                    categoryIcon: Icons.shopping_bag_outlined,
                    categoryColor: const Color(0xFFFB6B9D),
                    category: 'Grocery shopping app design',
                    title: 'Competitive Analysis',
                    time: '12:00 PM',
                    isCompleted: false,
                    status: const DSStatusTag.inProgress(),
                  ),
                  DSTaskCard(
                    categoryIcon: Icons.lock_outline,
                    categoryColor: const Color(0xFF8B5CF6),
                    category: 'Uber Eats redesign challange',
                    title: 'Create Low-fidelity Wireframe',
                    time: '07:00 PM',
                    isCompleted: false,
                    status: const DSStatusTag.todo(),
                  ),
                  DSTaskCard(
                    categoryIcon: Icons.menu_book_outlined,
                    categoryColor: const Color(0xFFF59E0B),
                    category: 'About design sprint',
                    title: 'How to pitch a Design Sprint',
                    time: '09:00 PM',
                    isCompleted: false,
                    status: const DSStatusTag.todo(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom bar + center FAB
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DSColor.primary, DSColor.accent],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: DSShadow.floating(DSColor.primary),
        ),
        child: FloatingActionButton(
          onPressed: () {},
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: _BottomBar(),
    );
  }
}

class _DateItem extends StatelessWidget {
  final String m, d, w;
  final bool selected;
  const _DateItem(String month, String day, String week, {this.selected = false})
      : m = month,
        d = day,
        w = week;

  @override
  Widget build(BuildContext context) {
    return DSDatePill(month: m, day: d, week: w, selected: selected);
  }
}

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BottomAppBar(
        color: DSColor.getSurface(Theme.of(context).brightness).withOpacity(0.9),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _BarIcon(Icons.home_filled),
              _BarIcon(Icons.calendar_month_rounded),
              SizedBox(width: 36),
              _BarIcon(Icons.group_outlined),
              _BarIcon(Icons.account_circle_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  const _BarIcon(this.icon);
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DSColor.getSurfaceTint(brightness),
        borderRadius: DSRadius.round,
      ),
      child: Icon(icon, color: DSColor.primary),
    );
  }
}

