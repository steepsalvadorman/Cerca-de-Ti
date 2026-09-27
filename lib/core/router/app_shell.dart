import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cerca/presentation/widgets/cerca_text_styles.dart';
import '../../features/chat/application/chat_controller.dart';
import '../../features/chat/presentation/screens/chats_screen.dart';
import '../theme/app_colors.dart';

/// One tab of a [AppShell]'s bottom navigation bar.
class AppShellTab {
  const AppShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.showsUnreadChats = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Badge the icon with the total of unread chat messages.
  final bool showsUnreadChats;
}

/// Persistent bottom-tab shell wrapping go_router's [StatefulNavigationShell],
/// used for both the client's (Inicio/Cuenta) and technician's
/// (Trabajos/Perfil) hub screens — replacing the header-avatar shortcuts
/// that used to be the only way to move between them.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell, required this.tabs});

  final StatefulNavigationShell navigationShell;
  final List<AppShellTab> tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching this keeps the inbox polling from any tab, so the badge
    // shows up without having to open "Mensajes" first.
    final unreadChats = ref.watch(chatUnreadTotalProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.cercaBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      tab: tabs[i],
                      badge: tabs[i].showsUnreadChats ? unreadChats : 0,
                      active: i == navigationShell.currentIndex,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
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

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.badge, required this.active, required this.onTap});

  final AppShellTab tab;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.cercaPrimary : AppColors.cercaTextMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(active ? tab.activeIcon : tab.icon, color: color, size: 22),
              if (badge > 0) Positioned(top: -5, left: 13, child: UnreadBadge(count: badge)),
            ],
          ),
          const SizedBox(height: 3),
          Text(tab.label, style: CercaText.sora(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
