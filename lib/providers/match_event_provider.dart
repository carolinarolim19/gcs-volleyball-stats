import 'package:flutter/material.dart';

import '../database/match_event_repository.dart';
import '../models/match_event.dart';

class MatchEventProvider extends ChangeNotifier {
  final MatchEventRepository _repository = MatchEventRepository();

  List<MatchEvent> _events = [];

  List<MatchEvent> get events => _events;

  Future<void> loadEvents(int matchId) async {
    _events = await _repository.getByMatch(matchId);
    notifyListeners();
  }

  Future<int> addEvent(MatchEvent event) async {
    final eventId = await _repository.insert(event);

    await loadEvents(event.matchId);

    return eventId;
  }

  Future<void> deleteAll(int matchId) async {
    await _repository.deleteAllFromMatch(matchId);
    await loadEvents(matchId);
  }

  Future<void> deleteEvent(
      int eventId,
      int matchId,
      ) async {
    await _repository.deleteById(eventId);
    await loadEvents(matchId);
  }

  Future<void> updateEventResult(
      int eventId,
      int matchId,
      String result,
      ) async {
    await _repository.updateResult(
      eventId,
      result,
    );

    await loadEvents(matchId);
  }
}