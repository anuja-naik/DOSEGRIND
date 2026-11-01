import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grinding_session.dart';

class HistoryService {
  static const _key = 'dosegrind.sessions.v1';
  Future<List<GrindingSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List<dynamic>).map((e) => GrindingSession.fromJson(Map<String, dynamic>.from(e as Map))).toList()..sort((a,b) => b.startedAt.compareTo(a.startedAt)); }
    catch (_) { return []; }
  }
  Future<void> save(GrindingSession session) async {
    final all = await load(); all.insert(0, session);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.take(250).map((s) => s.toJson()).toList()));
  }
  Future<void> delete(String id) async {
    final all = await load(); all.removeWhere((s) => s.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((s) => s.toJson()).toList()));
  }
}
