import 'package:flutter/material.dart';

import 'home_page.dart';
import 'statistics_page.dart';

/// پوسته اصلی برنامه با نوار ناوبری پایین (اقساط و آمار)
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  static const int _homeIndex = 0;
  static const int _statisticsIndex = 1;

  int _index = _homeIndex;

  /// صفحه آمار فقط از اولین انتخاب به بعد ساخته می‌شود
  bool _statisticsVisited = false;

  /// با هر ورود به تب آمار، صفحه از نو ساخته می‌شود تا آمار تازه محاسبه شود
  int _statisticsGeneration = 0;

  void _onDestinationSelected(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      if (index == _statisticsIndex) {
        _statisticsVisited = true;
        _statisticsGeneration++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          if (_statisticsVisited)
            StatisticsPage(key: ValueKey(_statisticsGeneration))
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'اقساط',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'آمار',
          ),
        ],
      ),
    );
  }
}
