import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _paths = ['/monitor', '/map', '/history', '/profile'];

  int get _selectedIndex {
    final index = _paths.indexWhere((path) => location.startsWith(path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => context.go(_paths[index]),
          destinations: const [
            NavigationDestination(
              key: Key('nav-monitor'),
              icon: Icon(Icons.center_focus_strong_outlined),
              selectedIcon: Icon(Icons.center_focus_strong_rounded),
              label: 'Monitor',
            ),
            NavigationDestination(
              key: Key('nav-map'),
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              key: Key('nav-history'),
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              key: Key('nav-profile'),
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
