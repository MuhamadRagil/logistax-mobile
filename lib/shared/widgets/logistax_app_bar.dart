import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/badge_providers.dart';

/// AppBar konsisten: judul + lonceng notifikasi dengan badge unread.
class LogistaxAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const LogistaxAppBar({super.key, required this.title, this.actions, this.leading, this.bottom});

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;

    return AppBar(
      title: Text(title),
      leading: leading,
      bottom: bottom,
      actions: [
        ...?actions,
        IconButton(
          tooltip: 'Notifikasi',
          onPressed: () {
            context.push('/notifikasi');
            // refresh badge saat kembali
            Future.delayed(const Duration(seconds: 1), () {
              ref.invalidate(unreadNotificationsProvider);
            });
          },
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_rounded),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
