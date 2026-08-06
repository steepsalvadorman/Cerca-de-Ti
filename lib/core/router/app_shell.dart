import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cerca/presentation/widgets/cerca_text_styles.dart';
import '../theme/app_colors.dart';

/// One tab of a [AppShell]'s bottom navigation bar.
class AppShellTab {
  const AppShellTab({required this.label, required this.icon, required this.activeIcon});

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Persistent bottom-tab shell wrapping go_router's [StatefulNavigationShell],
/// used for both the client's (Inicio/Cuenta) and technician's
/// (Trabajos/Perfil) hub screens — replacing the header-avatar shortcuts
/// that used to be the only way to move between them.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell, required this.tabs});

  final StatefulNavigationShell navigationShell;
  final List<AppShellTab> tabs;

  @override
  Widget build(BuildContext context) {
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
  const _TabButton({required this.tab, required this.active, required this.onTap});

  final AppShellTab tab;
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
          Icon(active ? tab.activeIcon : tab.icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(tab.label, style: CercaText.sora(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
