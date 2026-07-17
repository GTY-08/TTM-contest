import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../settings_copy.dart';
import '../widgets/settings_tab_views.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late bool _developerMode;

  List<Tab> get _tabs => [
    const Tab(text: '계정'),
    const Tab(text: '알림'),
    const Tab(text: '작업'),
    const Tab(text: '표시'),
    const Tab(text: '앱'),
    if (_developerMode) const Tab(text: '개발'),
  ];

  @override
  void initState() {
    super.initState();
    _developerMode = ref.read(developerModeProvider);
    _tab = _newController(widget.initialTab);
  }

  TabController _newController(int preferredIndex) {
    final tabs = _tabs;
    return TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: preferredIndex.clamp(0, tabs.length - 1),
    );
  }

  void _syncDeveloperMode(bool enabled) {
    if (_developerMode == enabled) return;
    final oldIndex = _tab.index;
    _tab.dispose();
    setState(() {
      _developerMode = enabled;
      _tab = _newController(oldIndex);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(developerModeProvider, (_, next) {
      if (mounted) _syncDeveloperMode(next);
    });

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          SettingsCopy.appBarTitle,
          style: TtmTypography.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: colors.outlineVariant.withValues(alpha: 0.35),
          indicatorColor: colors.primary,
          indicatorWeight: 2.5,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          splashFactory: InkRipple.splashFactory,
          labelStyle: TtmTypography.label.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TtmTypography.label.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const SettingsAccountTab(),
          const SettingsNotificationsTab(),
          const SettingsWorkerTab(),
          const SettingsDisplayTab(),
          const SettingsAppTab(),
          if (_developerMode) const SettingsDeveloperTab(),
        ],
      ),
    );
  }
}
