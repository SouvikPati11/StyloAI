import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../create/create_hub_screen.dart';
import '../looks/looks_screen.dart';
import '../profile/profile_screen.dart';

/// Bottom-nav shell: Home · Explore · Create · Looks · Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _tabs = const [
    HomeScreen(),
    ExploreScreen(),
    CreateHubScreen(),
    LooksScreen(),
    ProfileScreen(),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _select,
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explore'),
            BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'Create'),
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view),
                label: 'Looks'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// A shared scaffold body padding helper.
class ScreenBody extends StatelessWidget {
  final Widget child;
  const ScreenBody({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: child);
}
