import 'package:flutter/material.dart';

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
        decoration: const BoxDecoration(
          color: BrandColors.surface,
          border: Border(top: BorderSide(color: BrandColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      spec: _tabs[i],
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
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
    final color = selected ? BrandColors.ocean : BrandColors.inkFaint;
    return InkResponse(
      onTap: onTap,
      radius: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? spec.activeIcon : spec.icon, color: color, size: 25),
          const SizedBox(height: 3),
          Text(spec.label,
              style: AppTypography.body(11,
                  weight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
