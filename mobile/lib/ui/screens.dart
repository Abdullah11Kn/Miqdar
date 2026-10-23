import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'diary_and_detail_screen.dart';
import 'home_screen.dart';
import 'insights_and_goals_screen.dart';
import 'profile_and_device_screen.dart';
import 'scan_and_add_screen.dart';

export 'auth_screens.dart';
export 'diary_and_detail_screen.dart';
export 'home_screen.dart';
export 'insights_and_goals_screen.dart';
export 'profile_and_device_screen.dart';
export 'scan_and_add_screen.dart';

/// Responsive Main Application Shell (Section 4.1 & DES-04):
/// - Compact screens (< 720 px): Bottom NavigationBar with Home, Diary, Add Meal, Insights, Profile.
/// - Medium/Wide screens (>= 720 px): Sleek NavigationRail / Sidebar + multi-column content area.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 5 Primary Destinations (Section 4.1):
    // 0: Home
    // 1: Add / Capture
    // 2: Diary
    // 3: Insights
    // 4: Profile
    final pages = [
      HomeScreen(
        onScan: () => setState(() => index = 1),
        onOpenTab: (newIdx) => setState(() => index = newIdx),
      ),
      const ScanScreen(),
      const HistoryScreen(),
      const TrendsScreen(embedded: true),
      const ProfileScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopSidebar = constraints.maxWidth >= 780;

        if (isDesktopSidebar) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 248,
                    decoration: BoxDecoration(
                      color: isDark ? MiqdarColors.darkSurface : Colors.white,
                      border: BorderDirectional(
                        end: BorderSide(
                          color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MiqdarColors.border),
                              ),
                              child: Image.asset('assets/branding/miqdar-logo.png'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.appNameDual,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: MiqdarColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'v3.0 • Smart Nutrition',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() => index = 1),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(s.navAdd),
                        ),
                        const SizedBox(height: 18),
                        _SidebarItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: s.navHome,
                          selected: index == 0,
                          onTap: () => setState(() => index = 0),
                        ),
                        _SidebarItem(
                          icon: Icons.center_focus_weak_rounded,
                          selectedIcon: Icons.center_focus_strong_rounded,
                          label: s.navAdd,
                          selected: index == 1,
                          onTap: () => setState(() => index = 1),
                        ),
                        _SidebarItem(
                          icon: Icons.calendar_today_outlined,
                          selectedIcon: Icons.calendar_month_rounded,
                          label: s.navDiary,
                          selected: index == 2,
                          onTap: () => setState(() => index = 2),
                        ),
                        _SidebarItem(
                          icon: Icons.insights_outlined,
                          selectedIcon: Icons.insights_rounded,
                          label: s.navInsights,
                          selected: index == 3,
                          onTap: () => setState(() => index = 3),
                        ),
                        _SidebarItem(
                          icon: Icons.person_outline_rounded,
                          selectedIcon: Icons.person_rounded,
                          label: s.navProfile,
                          selected: index == 4,
                          onTap: () => setState(() => index = 4),
                        ),
                        const Spacer(),
                        const Divider(),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: Badge(
                            isLabelVisible: controller.unreadAlertsCount > 0,
                            label: Text('${controller.unreadAlertsCount}'),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: MiqdarColors.primary,
                            ),
                          ),
                          title: Text(
                            s.navNotices,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(s.navNotices)),
                                body: const SafeArea(child: AlertsScreen()),
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.scale_rounded, color: MiqdarColors.primary),
                          title: Text(
                            controller.scaleDevice.deviceId,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${controller.scaleDevice.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: IndexedStack(index: index, children: pages),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Compact Mobile Layout (< 780 px)
        return Scaffold(
          body: SafeArea(child: IndexedStack(index: index, children: pages)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: s.navHome,
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MiqdarColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: MiqdarColors.primary, size: 20),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: MiqdarColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                ),
                label: s.navAdd,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_today_outlined),
                selectedIcon: const Icon(Icons.calendar_month_rounded),
                label: s.navDiary,
              ),
              NavigationDestination(
                icon: const Icon(Icons.insights_outlined),
                selectedIcon: const Icon(Icons.insights_rounded),
                label: s.navInsights,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: s.navProfile,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? (isDark
                ? MiqdarColors.emeraldBright.withValues(alpha: 0.18)
                : MiqdarColors.softGreen)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected
                      ? (isDark ? MiqdarColors.mintGlow : MiqdarColors.primary)
                      : (isDark ? MiqdarColors.darkMuted : MiqdarColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? (isDark ? MiqdarColors.mintGlow : MiqdarColors.primary)
                          : (isDark ? Colors.white : MiqdarColors.dark),
                    ),
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
