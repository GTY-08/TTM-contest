import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/widget/ttm_widget_sync_service.dart';
import '../../../data/providers/home_navigation_provider.dart';
import '../../../features/match/providers/match_providers.dart';
import '../../../features/profile/screens/profile_tab_body.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../../../shared/widgets/ttm_ops_bottom_nav.dart';
import '../widgets/activity_tab_body.dart';
import '../widgets/dashboard_home_body.dart';
import '../widgets/request_browse_tab_body.dart';
import '../widgets/request_tab_body.dart';
import '../widgets/wallet_tab_body.dart';

/// 홈 6탭 — 홈 / 맡기기 / 찾기 / 활동 / 지갑 / 프로필.
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
    _TabDef('맡기기', 'assets/icons/plus_circle.svg', Icons.add_circle_outline),
    _TabDef('찾기', 'assets/icons/search.svg', Icons.search_outlined),
    _TabDef('활동', 'assets/icons/check_circle.svg', Icons.payments_outlined),
    _TabDef('지갑', '', Icons.account_balance_wallet_outlined),
    _TabDef('프로필', 'assets/icons/user.svg', Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabs.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeTabIndexProvider.notifier).state = _index;
      unawaited(_syncWorkWidget());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabIndexProvider, (prev, next) {
      if (next != _index && next >= 0 && next < _tabs.length) {
        setState(() => _index = next);
      }
    });

    final hasActive =
        ref.watch(myActiveMatchedRequestsProvider).valueOrNull?.isNotEmpty ??
        false;

    ref.listen(myActiveMatchedRequestsProvider, (prev, next) {
      unawaited(_syncWorkWidget());
    });
    ref.listen(myGeneralApplicationsProvider, (prev, next) {
      unawaited(_syncWorkWidget());
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      appBar: (_index == 0 || _index == 1)
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
      body: AnimatedSwitcher(
        duration: TtmMotion.standard,
        switchInCurve: TtmMotion.easeOut,
        switchOutCurve: TtmMotion.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _bodyFor(_index),
        ),
      ),
      bottomNavigationBar: TtmOpsBottomNav(
        selectedIndex: _index,
        onSelected: (i) {
          ref.read(homeTabIndexProvider.notifier).state = i;
          setState(() => _index = i);
        },
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            TtmOpsNavDestination(
              label: _tabs[i].label,
              iconWidget: _tabIcon(
                _tabs[i],
                selected: false,
                badge: i == 3 && hasActive,
              ),
              selectedIconWidget: _tabIcon(
                _tabs[i],
                selected: true,
                badge: i == 3 && hasActive,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _syncWorkWidget() async {
    final active =
        ref.read(myActiveMatchedRequestsProvider).valueOrNull ?? const [];
    final applications =
        ref.read(myGeneralApplicationsProvider).valueOrNull ?? const [];
    await TtmWidgetSyncService.syncWorkItems(
      activeRequests: active,
      applications: applications,
    );
  }

  Widget _tabIcon(_TabDef t, {required bool selected, bool badge = false}) {
    final colors = Theme.of(context).colorScheme;
    final c = selected ? colors.primary : colors.onSurfaceVariant;

    Widget icon;
    if (t.label == '홈' ||
        t.label == '맡기기' ||
        t.label == '찾기' ||
        t.label == '프로필') {
      icon = SvgPicture.asset(
        t.asset,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      );
    } else {
      icon = Icon(t.materialIcon, size: 22, color: c);
    }

    if (!badge) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -2,
          right: -4,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF6B6B),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bodyFor(int index) {
    switch (index) {
      case 0:
        return const DashboardHomeBody();
      case 1:
        return const RequestTabBody();
      case 2:
        return const RequestBrowseTabBody();
      case 3:
        return const ActivityTabBody();
      case 4:
        return const WalletTabBody();
      case 5:
        return const ProfileTabBody();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TabDef {
  const _TabDef(this.label, this.asset, this.materialIcon);
  final String label;
  final String asset;
  final IconData materialIcon;
}
