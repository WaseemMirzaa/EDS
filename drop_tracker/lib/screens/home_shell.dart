import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/brand.dart';
import 'history_screen.dart';
import 'medications_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec('Today', Icons.wb_sunny_outlined, Icons.wb_sunny_rounded),
    _TabSpec('History', Icons.insights_outlined, Icons.insights_rounded),
    _TabSpec('Meds', Icons.medication_outlined, Icons.medication_rounded),
    _TabSpec('Settings', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TodayScreen(),
          HistoryScreen(),
          MedicationsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: BrandColors.surface,
          boxShadow: [
            BoxShadow(
              color: BrandColors.ocean.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        spec: _tabs[i],
                        selected: _index == i,
                        onTap: () {
                          if (_index == i) return;
                          HapticFeedback.selectionClick();
                          setState(() => _index = i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabSpec(this.label, this.icon, this.activeIcon);
}

class _NavItem extends StatelessWidget {
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.spec, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? BrandColors.primary : BrandColors.inkFaint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? spec.activeIcon : spec.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(spec.label,
              style: AppTypography.body(11.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 3,
            width: selected ? 18 : 0,
            decoration: BoxDecoration(
              color: BrandColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
