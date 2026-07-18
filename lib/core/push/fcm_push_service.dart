import 'dart:io';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/repositories/fcm_token_repository.dart';
import 'push_channels.dart';
import 'push_route_handler.dart';

/// 백그라운드 isolate 진입점 (top-level 필수).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase는 main()에서 이미 initialize 됨. 백그라운드 핸들러는 최소 처리.
}

/// FCM 수신·토큰·로컬 알림·딥링크 (카카오T·Uber 서버 푸시 패턴의 클라이언트 측).
class FcmPushService {
  FcmPushService({required this._tokenRepository, required this._onNavigate});

  final FcmTokenRepository _tokenRepository;
  final void Function(PushNavigationIntent intent) _onNavigate;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    await _setupLocalNotifications();
    await _requestPermission();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _messaging.onTokenRefresh.listen(_syncTokenToServer);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleNavigation(initial.data);
    }

    _initialized = true;
  }

  Future<void> bindUserSession(String? userId) async {
    if (!_initialized) return;
    if (userId == null) {
      await _unregisterCurrentToken();
      return;
    }
    await _syncTokenToServer(await _messaging.getToken());
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    }
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('ic_stat_ttm');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _onNavigate(PushNavigationIntent.fromData({'route': payload}));
      },
    );

    if (Platform.isAndroid) {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          PushChannels.matchOffer,
          '근처 심부름',
          description: '활동 중일 때 주변 심부름 제안',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          PushChannels.matchResult,
          '매칭 결과',
          description: '매칭 성공·실패·취소',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          PushChannels.message,
          '메시지',
          description: '진행 중 심부름 대화',
          importance: Importance.defaultImportance,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          PushChannels.completion,
          '완료',
          description: '작업 완료 확인',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          PushChannels.defaultChannel,
          '틈틈 알림',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  Future<void> _syncTokenToServer(String? token) async {
    if (token == null || token.isEmpty) return;
    _currentToken = token;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await _tokenRepository.upsertToken(token: token, platform: platform);
    } catch (e, st) {
      debugPrint('[FcmPushService] token upsert failed: $e\n$st');
    }
  }

  Future<void> _unregisterCurrentToken() async {
    final token = _currentToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await _tokenRepository.deleteToken(token);
    } catch (e) {
      debugPrint('[FcmPushService] token delete failed: $e');
    }
    _currentToken = null;
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    if (notification == null) return;

    final channelId = _channelForType(data['push_type']?.toString() ?? '');
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelLabel(channelId),
          icon: 'ic_stat_ttm',
          color: Color(0xFF0B7A75),
          importance: Importance.high,
          priority: Priority.high,
          tag: data['request_id']?.toString(),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data['route']?.toString(),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleNavigation(message.data);
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final intent = PushNavigationIntent.fromData(data);
    _onNavigate(intent);
  }

  String _channelForType(String pushType) {
    switch (pushType) {
      case PushTypes.workerMatchOffer:
      case PushTypes.exerciseMatchOffer:
      case PushTypes.raidRecruitmentOffer:
        return PushChannels.matchOffer;
      case PushTypes.requesterMatched:
      case PushTypes.requesterMatchFailed:
      case PushTypes.requestCancelled:
      case PushTypes.exerciseMatchMatched:
      case PushTypes.raidRecruitmentApplication:
      case PushTypes.raidApplicationReceived:
      case PushTypes.raidApplicationApproved:
      case PushTypes.raidApplicationWaitlisted:
      case PushTypes.raidApplicationRejected:
      case PushTypes.raidParticipantJoined:
      case PushTypes.raidParticipantCancelled:
        return PushChannels.matchResult;
      case PushTypes.chatMessage:
      case PushTypes.exerciseMatchMessage:
      case PushTypes.raidApplicationMessage:
        return PushChannels.message;
      case PushTypes.completionRequested:
      case PushTypes.requestCompleted:
      case PushTypes.raidStarted:
        return PushChannels.completion;
      default:
        return PushChannels.defaultChannel;
    }
  }

  String _channelLabel(String channelId) {
    switch (channelId) {
      case PushChannels.matchOffer:
        return '근처 심부름';
      case PushChannels.matchResult:
        return '매칭 결과';
      case PushChannels.message:
        return '메시지';
      case PushChannels.completion:
        return '완료';
      default:
        return '틈틈 알림';
    }
  }
}
