import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Stream controller for notifications
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Store received messages
  final List<ReceivedNotification> _receivedMessages = [];
  List<ReceivedNotification> get receivedMessages => _receivedMessages;

  // Callback for UI updates
  Function? onNewMessage;

  Future<void> initialize() async {
    // Request permission
    await _requestPermission();

    // Get token
    await _getToken();

    // Setup handlers
    _setupForegroundHandler();
    _setupBackgroundHandler();
    _setupTokenRefresh();

    // Load saved messages
    await _loadSavedMessages();
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ Provisional permission granted');
    } else {
      print('❌ User declined or has not granted permission');
    }
  }

  Future<void> _getToken() async {
    _fcmToken = await _firebaseMessaging.getToken();
    print('📱 FCM Token: $_fcmToken');

    // Save token locally
    if (_fcmToken != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', _fcmToken!);
    }
  }

  Future<void> _setupTokenRefresh() async {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('🔄 Token refreshed: $newToken');
    });
  }

  void _setupForegroundHandler() {
    // When app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Foreground message received');
      _handleMessage(message);
      _messageStreamController.add(message);
      if (onNewMessage != null) onNewMessage!();
    });

    // When app is opened from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print('📨 App opened from terminated state');
        _handleMessage(message);
        _messageStreamController.add(message);
      }
    });

    // When app is in background and opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📨 App opened from background');
      _handleMessage(message);
      _messageStreamController.add(message);
      if (onNewMessage != null) onNewMessage!();
    });
  }

  @pragma('vm:entry-point')
  static void _setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _handleMessage(RemoteMessage message) {
    final notification = ReceivedNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: message.notification?.title ?? 'No Title',
      body: message.notification?.body ?? 'No Body',
      data: message.data,
      timestamp: DateTime.now(),
    );

    _receivedMessages.insert(0, notification);
    _saveMessages();
  }

  Future<void> _saveMessages() async {
    await SharedPreferences.getInstance();
    // Save only last 20 messages
    _receivedMessages.take(20).toList();
    // For simplicity, we're not implementing full serialization here
    // In production, use JSON serialization
  }

  Future<void> _loadSavedMessages() async {
    await SharedPreferences.getInstance();
    // Load saved messages (simplified)
    _receivedMessages.clear();
  }

  Future<void> refreshToken() async {
    await _getToken();
  }

  void dispose() {
    _messageStreamController.close();
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Background message received: ${message.notification?.title}");
  print("📝 Message data: ${message.data}");
}

// Model class for received notifications
class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    required this.timestamp,
  });
}
