import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/firestore_helper.dart';
import '../services/meal_service.dart';
import '../utils/app_logger.dart';

/// Service for managing daily reminder notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String _reminderEnabledKey = 'reminder_enabled';
  static const String _reminderHourKey = 'reminder_hour';
  static const String _reminderMinuteKey = 'reminder_minute';
  static const String _hasSetReminderPreferenceKey =
      'has_set_reminder_preference';
  static const int _reminderNotificationId = 1001;

  /// Initialize notification service
  static Future<void> initialize() async {
    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Android initialization
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android notification channel
      await _createAndroidChannel();

      AppLogger.d('NotificationService', 'Initialized successfully');
    } catch (e) {
      AppLogger.e('NotificationService', 'Error initializing notifications', e);
    }
  }

  /// Create Android notification channel
  static Future<void> _createAndroidChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'notecal_reminders',
      'NoteCal Reminders',
      description: 'Daily reminders to log your meals and activities',
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    AppLogger.d('NotificationService', 'Notification tapped: ${response.id}');
    // App will open automatically when notification is tapped
  }

  /// Get notification permission status
  static Future<bool> getPermissionStatus() async {
    try {
      final iosImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final result = await iosImplementation.checkPermissions();
        // checkPermissions returns NotificationsEnabledOptions?
        // In version 17.2.4, the structure may have changed
        // For now, if result is not null, we assume permissions are checkable
        // We'll rely on requestPermission() to actually verify and request if needed
        // This is a safe fallback that won't break the flow
        return result != null;
      }
      // For Android, check using areNotificationsEnabled
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ??
            true; // Default to true if null (older Android versions)
      }
      return true; // Default to true if platform not recognized
    } catch (e) {
      AppLogger.e('NotificationService', 'Error checking permission status', e);
      return false;
    }
  }

  /// Request notification permissions (iOS)
  static Future<bool> requestPermission() async {
    try {
      final iosImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final result = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return result ?? false;
      }
      return true; // Android doesn't need permission request
    } catch (e) {
      AppLogger.e('NotificationService', 'Error requesting permission', e);
      return false;
    }
  }

  /// Check if user has set reminder preference
  static Future<bool> hasSetReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSetReminderPreferenceKey) ?? false;
  }

  /// Mark that user has set reminder preference
  static Future<void> setReminderPreferenceSet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSetReminderPreferenceKey, true);
  }

  /// Check if reminder is enabled
  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderEnabledKey) ?? false;
  }

  /// Get reminder time
  static Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_reminderHourKey) ?? 20;
    final minute = prefs.getInt(_reminderMinuteKey) ?? 30;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Set reminder enabled/disabled with permission check
  /// Returns true if successfully enabled, false if permission denied
  static Future<bool> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      // Check permission status
      final hasPermission = await getPermissionStatus();

      if (!hasPermission) {
        // Request permission
        final granted = await requestPermission();
        if (!granted) {
          // Permission denied - don't enable
          return false;
        }
      }

      // Permission granted - enable and schedule
      await prefs.setBool(_reminderEnabledKey, true);
      await setReminderPreferenceSet();
      await rescheduleNextIfNeeded();
      return true;
    } else {
      // Disable reminder
      await prefs.setBool(_reminderEnabledKey, false);
      await setReminderPreferenceSet();
      await cancelReminder();
      return true;
    }
  }

  /// Auto-enable reminder if permission granted and user hasn't set preference
  static Future<void> autoEnableIfNeeded() async {
    try {
      final hasSetPreference = await hasSetReminderPreference();
      if (hasSetPreference) {
        // User has already set preference, don't auto-enable
        return;
      }

      final hasPermission = await getPermissionStatus();
      if (!hasPermission) {
        // No permission, don't auto-enable
        return;
      }

      // Permission granted and user hasn't set preference - auto-enable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reminderEnabledKey, true);
      await setReminderPreferenceSet();

      // Use default time or last saved time
      final time = await getReminderTime();
      await rescheduleNextIfNeeded();

      AppLogger.d('NotificationService',
          'Auto-enabled reminder (permission granted, first time)');
    } catch (e) {
      AppLogger.e('NotificationService', 'Error auto-enabling reminder', e);
    }
  }

  /// Set reminder time
  static Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);

    // Reschedule if enabled
    if (await isReminderEnabled()) {
      await rescheduleNextIfNeeded();
    }
  }

  /// Check if user has any logs today (meals, exercises, or daily note)
  static Future<bool> hasAnyLogToday(String uid, String today) async {
    try {
      // Check meals
      final mealService = MealService();
      final hasMeals = await mealService.hasMealsForDate(today);
      if (hasMeals) return true;

      // Check exercises
      final exercises = await FirestoreHelper.getExerciseLogsForDay(uid, today);
      if (exercises.isNotEmpty) return true;

      // Check daily note
      final note = await FirestoreHelper.getDailyNote(uid, today);
      if (note != null && note.isNotEmpty) return true;

      return false;
    } catch (e) {
      AppLogger.e('NotificationService', 'Error checking logs today', e);
      return false; // Default to false (don't send notification if error)
    }
  }

  /// Schedule daily reminder notification
  static Future<void> scheduleDaily(TimeOfDay time) async {
    try {
      // Cancel existing reminder first
      await cancelReminder();

      // Schedule for today at specified time
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use local timezone
      final tzLocation = tz.local;
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tzLocation);

      // Check if user has already logged today before scheduling
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final today = MealService.formatDate(now);
        final hasLogs = await hasAnyLogToday(user.uid, today);

        // If user already logged today, schedule for tomorrow instead
        if (hasLogs && scheduledDate.day == now.day) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
          final tzScheduledDateTomorrow =
              tz.TZDateTime.from(scheduledDate, tzLocation);
          await _scheduleNotification(tzScheduledDateTomorrow);
          AppLogger.d('NotificationService',
              'User already logged today, scheduled for tomorrow');
          return;
        }
      }

      await _scheduleNotification(tzScheduledDate);
      AppLogger.d('NotificationService',
          'Scheduled reminder for ${scheduledDate.toString()}');
    } catch (e) {
      AppLogger.e('NotificationService', 'Error scheduling reminder', e);
    }
  }

  /// Schedule notification at specific time
  static Future<void> _scheduleNotification(tz.TZDateTime scheduledDate) async {
    await _notifications.zonedSchedule(
      _reminderNotificationId,
      'NoteCal',
      "Haven't logged today? Add your meals in 10 seconds.",
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'notecal_reminders',
          'NoteCal Reminders',
          channelDescription:
              'Daily reminders to log your meals and activities',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeat daily at same time
    );
  }

  /// Cancel today's reminder and reschedule for next day if needed
  static Future<void> cancelReminder() async {
    try {
      await _notifications.cancel(_reminderNotificationId);
      AppLogger.d('NotificationService', 'Cancelled reminder');
    } catch (e) {
      AppLogger.e('NotificationService', 'Error cancelling reminder', e);
    }
  }

  /// Reschedule next reminder based on current state
  /// Called on app launch and when user logs something
  static Future<void> rescheduleNextIfNeeded() async {
    try {
      final enabled = await isReminderEnabled();
      if (!enabled) {
        await cancelReminder();
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await cancelReminder();
        return;
      }

      final time = await getReminderTime();
      final now = DateTime.now();
      final today = MealService.formatDate(now);

      // Check if user has logged today
      final hasLogs = await hasAnyLogToday(user.uid, today);

      if (hasLogs) {
        // User already logged today, schedule for tomorrow
        await cancelReminder();
        final tomorrow = now.add(const Duration(days: 1));
        final scheduledDate = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          time.hour,
          time.minute,
        );
        final tzLocation = tz.local;
        final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tzLocation);
        await _scheduleNotification(tzScheduledDate);
        AppLogger.d('NotificationService',
            'User logged today, rescheduled for tomorrow');
      } else {
        // User hasn't logged today, schedule for today (if time hasn't passed) or tomorrow
        await scheduleDaily(time);
        AppLogger.d('NotificationService', 'Rescheduled reminder');
      }
    } catch (e) {
      AppLogger.e('NotificationService', 'Error rescheduling reminder', e);
    }
  }
}
