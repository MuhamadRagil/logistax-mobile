import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

/// Bottom navigation khusus intern — pola sama dengan `BottomNavShell` HR,
/// tapi widget terpisah supaya perubahan di sini tidak menyentuh navigasi
/// karyawan. Sertifikat dibuka dari tab Nilai/Profil/Beranda (bukan tab
/// sendiri) agar bottom nav tetap 5 item.
class InternShell extends StatelessWidget {
  const InternShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Beranda',
    ),
    NavigationDestination(
      icon: Icon(Icons.fingerprint),
      selectedIcon: Icon(Icons.fingerprint),
      label: 'Absensi',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_note_outlined),
      selectedIcon: Icon(Icons.event_note_rounded),
      label: 'Izin',
    ),
    NavigationDestination(
      icon: Icon(Icons.grade_outlined),
      selectedIcon: Icon(Icons.grade_rounded),
      label: 'Nilai',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          destinations: _destinations,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
