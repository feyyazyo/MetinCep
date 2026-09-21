import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../models/document_model.dart';
import '../history/history_screen.dart';
import '../processing/extraction_flow.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Alt menü: Ana Sayfa | Geçmiş | Ayarlar
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostCapture());
  }

  Future<void> _recoverLostCapture() async {
    if (!mounted) {
      return;
    }
    final picker = AppScope.of(context).picker;
    final paths = await picker.retrieveLostImages();
    if (!mounted || paths.isEmpty) {
      return;
    }
    await ExtractionFlow.processImages(context, paths, DocumentSource.camera);
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(onShowHistory: () => _selectTab(1)),
          const HistoryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Geçmiş'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
