import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_motion.dart';
import '../../../data/providers/home_navigation_provider.dart';
import '../../../features/profile/screens/profile_tab_body.dart';
import '../../../features/raid/screens/raid_activity_tab.dart';
import '../../../features/raid/screens/raid_browse_tab.dart';
import '../../../features/raid/screens/raid_create_tab.dart';
import '../../../features/raid/screens/raid_home_tab.dart';
import '../../../features/raid/screens/raid_reward_tab.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../../../shared/widgets/ttm_ops_bottom_nav.dart';

/// 레이드 중심의 틈틈 홈 셸.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _index;

  static const _tabs = [
    _TabDef('홈', 'assets/icons/home.svg', Icons.home_outlined),
    _TabDef('매칭 만들기', 'assets/icons/plus_circle.svg', Icons.add_circle_outline),
    _TabDef('찾기', 'assets/icons/search.svg', Icons.search_outlined),
    _TabDef('내 활동', 'assets/icons/check_circle.svg', Icons.directions_run),
    _TabDef('리워드', '', Icons.redeem_outlined),
    _TabDef('프로필', 'assets/icons/user.svg', Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabs.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeTabIndexProvider.notifier).state = _index;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      if (next != _index && next >= 0 && next < _tabs.length) {
        setState(() => _index = next);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      appBar: _index <= 2
          ? null
          : AppBar(
              title: Text(_tabs[_index].label),
              actions: [
                if (_index == 5)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
              ],
            ),
      body: SafeArea(
        top: _index <= 2,
        bottom: false,
        child: AnimatedSwitcher(
          duration: TtmMotion.standard,
          switchInCurve: TtmMotion.easeOut,
          switchOutCurve: TtmMotion.easeIn,
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: _bodyFor(_index),
          ),
        ),
      ),
      bottomNavigationBar: TtmOpsBottomNav(
        selectedIndex: _index,
        onSelected: (index) {
          ref.read(homeTabIndexProvider.notifier).state = index;
          setState(() => _index = index);
        },
        destinations: [
          for (final tab in _tabs)
            TtmOpsNavDestination(
              label: tab.label,
              iconWidget: _tabIcon(tab, selected: false),
              selectedIconWidget: _tabIcon(tab, selected: true),
            ),
        ],
      ),
    );
  }

  Widget _tabIcon(_TabDef tab, {required bool selected}) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;

    if (tab.asset.isNotEmpty) {
      return SvgPicture.asset(
        tab.asset,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(tab.materialIcon, size: 22, color: color);
  }

  Widget _bodyFor(int index) {
    return switch (index) {
      0 => const RaidHomeTab(),
      1 => const RaidCreateTab(),
      2 => const RaidBrowseTab(),
      3 => const RaidActivityTab(),
      4 => const RaidRewardTab(),
      5 => const ProfileTabBody(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TabDef {
  const _TabDef(this.label, this.asset, this.materialIcon);

  final String label;
  final String asset;
  final IconData materialIcon;
}
