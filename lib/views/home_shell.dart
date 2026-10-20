import 'package:flutter/material.dart';
import 'main_dashboard_view.dart';
import 'process_view.dart';
import 'project_list_view.dart';

/// 앱의 첫 화면: 아래 탭으로 [홈] [프로젝트] [프로세스]를 오간다.
/// 탭은 처음 열 때 만들고(앱 시작 때 서버를 부르지 않게), 그 뒤로는 스크롤·상태를 그대로 둔다.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _opened = {0};

  static const _pages = [MainDashboardView(), ProjectListView(), ProcessView()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < _pages.length; i++)
            TickerMode(
              enabled: i == _tab,
              child: _opened.contains(i) ? _pages[i] : const SizedBox.shrink(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _opened.add(i);
        }),
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: '프로젝트',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: '프로세스',
          ),
        ],
      ),
    );
  }
}
