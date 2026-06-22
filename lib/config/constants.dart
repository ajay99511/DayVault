import 'package:flutter/material.dart';
import '../models/types.dart';

class AppColors {
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);

  static const indigo500 = Color(0xFF6366F1);
  static const emerald500 = Color(0xFF10B981);
  static const rose500 = Color(0xFFF43F5E);
  static const amber500 = Color(0xFFF59E0B);
  static const fuchsia500 = Color(0xFFD946EF);
}

const Map<Mood, String> moodIcons = {
  Mood.euphoric: '🤩',
  Mood.happy: '🙂',
  Mood.productive: '⚡',
  Mood.neutral: '😐',
  Mood.tired: '😴',
  Mood.sad: '😢',
  Mood.anxious: '😰',
  Mood.angry: '😡',
  Mood.excited: '🎉',
  Mood.relaxed: '😌',
  Mood.social: '🥂',
  Mood.bored: '😒',
  Mood.creative: '🎨',
};

/// Human-readable label for a [TimeBucket] (e.g. earlyMorning -> "Early
/// Morning"). Used by the editor's time picker and the read-only displays so
/// they never surface raw enum text like "earlyMorning".
String timeBucketLabel(TimeBucket bucket) {
  switch (bucket) {
    case TimeBucket.midnight:
      return 'Midnight';
    case TimeBucket.earlyMorning:
      return 'Early Morning';
    case TimeBucket.morning:
      return 'Morning';
    case TimeBucket.afternoon:
      return 'Afternoon';
    case TimeBucket.evening:
      return 'Evening';
    case TimeBucket.night:
      return 'Night';
  }
}

/// Representative icon for a [TimeBucket], shown in the time picker.
IconData timeBucketIcon(TimeBucket bucket) {
  switch (bucket) {
    case TimeBucket.midnight:
      return Icons.bedtime;
    case TimeBucket.earlyMorning:
      return Icons.wb_twilight;
    case TimeBucket.morning:
      return Icons.wb_sunny;
    case TimeBucket.afternoon:
      return Icons.light_mode;
    case TimeBucket.evening:
      return Icons.nights_stay;
    case TimeBucket.night:
      return Icons.nightlight_round;
  }
}

const List<String> essentialFeelings = [
  "Grateful",
  "Inspired",
  "Accomplished",
  "Peaceful",
  "Loved",
  "Energetic",
  "Curious",
  "Hopeful",
  "Melancholic",
  "Frustrated",
  "Anxious",
  "Exhausted",
  "Lonely",
  "Confused",
];

class SecurityConstants {
  static const int pinLength = 4;
  static const int maxAttempts = 5;

  /// Base lockout duration (seconds) applied on the first lockout cycle.
  static const int lockoutDurationSeconds = 30;

  /// Upper bound for the escalating (exponential) lockout duration.
  static const int maxLockoutDurationSeconds = 3600; // 1 hour
}
