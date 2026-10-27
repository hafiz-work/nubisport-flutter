import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../activities/presentation/pages/feed_page.dart';
import '../auth/domain/models/app_user.dart';
import '../profile/presentation/pages/profile_page.dart';

/// Bottom navigation for the signed-in app. Feed is home; profile keeps the
/// dashboard content. iOS gets the Liquid Glass tab bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.user});
  final AppUser user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      // The glass pill floats over the page; Material's bar stays opaque and
      // outside the body.
      extendBody: isIOS,
      body: IndexedStack(
        index: _index,
        children: [
          const FeedPage(),
          ProfilePage(user: widget.user),
        ],
      ),
      bottomNavigationBar: isIOS
          ? SafeArea(
              top: false,
              child: GlassTabBar.bottom(
                selectedIndex: _index,
                onTabSelected: (index) => setState(() => _index = index),
                tabs: const [
                  GlassTab(
                    icon: Icon(Icons.dynamic_feed_outlined),
                    activeIcon: Icon(Icons.dynamic_feed),
                    label: 'Feed',
                  ),
                  GlassTab(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
            )
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: Icon(Icons.dynamic_feed),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}
