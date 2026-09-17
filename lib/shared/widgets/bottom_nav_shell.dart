import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../providers/badge_providers.dart';

/// Shell bottom navigation. Branch: 0 Beranda, 1 Absensi, 2 Cuti, 3 Tim (SPV), 4 Profil.
/// Tab "Tim" hanya tampil untuk role spv/hrd/super_admin.
class BottomNavShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final pendingLeave = ref.watch(myPendingLeaveCountProvider).value ?? 0;
    final showTeam = auth.canSeeTeam;

    // Map index tampilan → index branch router.
    final branchIndexes = showTeam ? const [0, 1, 2, 3, 4] : const [0, 1, 2, 4];
    var currentDisplay = branchIndexes.indexOf(navigationShell.currentIndex);
    if (currentDisplay < 0) currentDisplay = 0;

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Beranda',
      ),
      const NavigationDestination(
        icon: Icon(Icons.fingerprint),
        selectedIcon: Icon(Icons.fingerprint),
        label: 'Absensi',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: pendingLeave > 0,
          label: Text('$pendingLeave'),
          child: const Icon(Icons.calendar_month_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: pendingLeave > 0,
          label: Text('$pendingLeave'),
          child: const Icon(Icons.calendar_month),
        ),
        label: 'Cuti',
      ),
      if (showTeam)
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups_rounded),
          label: 'Tim',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profil',
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: currentDisplay,
          destinations: destinations,
          onDestinationSelected: (displayIndex) {
            final branch = branchIndexes[displayIndex];
            navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);
          },
        ),
      ),
    );
  }
}
