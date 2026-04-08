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
