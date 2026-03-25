import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:userinterface/services/notification_service.dart';

/// Shared logic for syncing attendance reminders.
/// Used by Dashboard and Settings so both use the same day-aware scheduling.
class AttendanceReminderSync {
  static const _weekdayLabel = <int, String>{
    DateTime.monday: "Mon",
    DateTime.tuesday: "Tue",
    DateTime.wednesday: "Wed",
    DateTime.thursday: "Thu",
    DateTime.friday: "Fri",
    DateTime.saturday: "Sat",
    DateTime.sunday: "Sun",
  };

  static Future<void> sync({
    required String baseUrl,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lecturer/$userId/schedule'),
      );

      if (response.statusCode != 200) return;

      final classes = jsonDecode(response.body) as List;
      await NotificationService.cancelAll();

      final now = DateTime.now();
      const weeksToScheduleAhead = 8;

      for (final cls in classes) {
        final classId = cls['id'] as int;
        final className = (cls['course_name'] ?? 'Class').toString();
        final scheduleStr = (cls['start_time'] ?? '').toString();

        final spec = _parseScheduleSpec(scheduleStr);
        if (spec == null) continue;

        final isTodaySelected = spec.weekdays.contains(now.weekday);
        if (isTodaySelected && _isNowWithinWindow(now, spec.start, spec.end)) {
          final taken = await _isAttendanceTakenToday(baseUrl, classId);
          if (!taken) {
            await NotificationService.showInstantNotification(
              "Class In Progress",
              'Your class "$className" is ongoing. Take attendance now.',
            );
          }
        }

        for (final weekday in spec.weekdays) {
          final nextStart = _nextWeekdayTime(
            from: now,
            weekday: weekday,
            time: spec.start,
          );

          for (int i = 0; i < weeksToScheduleAhead; i++) {
            final sessionDate = nextStart.add(Duration(days: 7 * i));
            final sessionEnd = DateTime(
              sessionDate.year,
              sessionDate.month,
              sessionDate.day,
              spec.end.hour,
              spec.end.minute,
            );

            if (sessionDate.isAfter(now)) {
              final startId = NotificationService.buildSessionNotificationId(
                classId: classId,
                sessionDate: sessionDate,
                type: 1,
              );
              await NotificationService.scheduleAttendanceStart(
                notificationId: startId,
                className: className,
                scheduledTime: sessionDate,
              );
            }

            final preEndTime = sessionEnd.subtract(const Duration(minutes: 10));
            if (preEndTime.isAfter(now)) {
              final preEndId = NotificationService.buildSessionNotificationId(
                classId: classId,
                sessionDate: sessionDate,
                type: 2,
              );
              await NotificationService.scheduleAttendancePreEnd(
                notificationId: preEndId,
                className: className,
                scheduledTime: preEndTime,
              );
            }
          }
        }
      }
      log("REMINDER-SYNC: Complete.");
    } catch (e) {
      log("REMINDER-SYNC: Failed -> $e");
    }
  }

  static Future<bool> _isAttendanceTakenToday(String baseUrl, int classId) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/attendance/taken?class_id=$classId'),
      );
      if (resp.statusCode != 200) return false;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['taken'] == true);
    } catch (_) {
      return false;
    }
  }

  static bool _isNowWithinWindow(DateTime now, TimeOfDay start, TimeOfDay end) {
    final startDt =
        DateTime(now.year, now.month, now.day, start.hour, start.minute);
    final endDt =
        DateTime(now.year, now.month, now.day, end.hour, end.minute);
    return now.isAfter(startDt) && now.isBefore(endDt);
  }

  static DateTime _nextWeekdayTime({
    required DateTime from,
    required int weekday,
    required TimeOfDay time,
  }) {
    final today =
        DateTime(from.year, from.month, from.day, time.hour, time.minute);
    int deltaDays = (weekday - from.weekday) % 7;
    DateTime candidate = today.add(Duration(days: deltaDays));
    if (!candidate.isAfter(from)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  static _ScheduleSpec? _parseScheduleSpec(String scheduleStr) {
    try {
      final raw = scheduleStr.trim();
      String daysPart = "";
      String timePart = raw;

      if (raw.contains("|")) {
        final parts = raw.split("|");
        daysPart = parts[0].trim();
        timePart = parts.sublist(1).join("|").trim();
      }

      final rangeParts = timePart.split("-");
      if (rangeParts.length < 2) return null;

      final startStr = rangeParts[0].trim();
      final endStr = rangeParts.sublist(1).join("-").trim();

      final start = _parseTimeOfDay(startStr);
      final end = _parseTimeOfDay(endStr);
      if (start == null || end == null) return null;

      final weekdays = <int>{};
      if (daysPart.isNotEmpty) {
        for (final t in daysPart
            .split(",")
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)) {
          final w = _weekdayFromLabel(t);
          if (w != null) weekdays.add(w);
        }
      }
      if (weekdays.isEmpty) {
        weekdays.add(DateTime.now().weekday);
      }
      return _ScheduleSpec(
        weekdays: weekdays.toList(),
        start: start,
        end: end,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _weekdayFromLabel(String label) {
    final normalized = label.toLowerCase();
    for (final entry in _weekdayLabel.entries) {
      if (entry.value.toLowerCase() == normalized) return entry.key;
    }
    switch (normalized) {
      case "monday":
        return DateTime.monday;
      case "tuesday":
        return DateTime.tuesday;
      case "wednesday":
        return DateTime.wednesday;
      case "thursday":
        return DateTime.thursday;
      case "friday":
        return DateTime.friday;
      case "saturday":
        return DateTime.saturday;
      case "sunday":
        return DateTime.sunday;
    }
    return null;
  }

  static TimeOfDay? _parseTimeOfDay(String s) {
    final v = s.trim();
    try {
      if (v.toLowerCase().contains("am") || v.toLowerCase().contains("pm")) {
        final dt = DateFormat('hh:mm a').parse(v);
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      final parts = v.split(":");
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }
}

class _ScheduleSpec {
  final List<int> weekdays;
  final TimeOfDay start;
  final TimeOfDay end;

  _ScheduleSpec({
    required this.weekdays,
    required this.start,
    required this.end,
  });
}