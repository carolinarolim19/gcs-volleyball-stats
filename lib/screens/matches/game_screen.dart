import 'package:flutter/material.dart';
import '../../widgets/action_result_sheet.dart';
import 'package:provider/provider.dart';

import '../../models/match_event.dart';
import '../../providers/match_event_provider.dart';
import '../../models/player.dart';
import '../../providers/match_lineup_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/match_libero_provider.dart';
import '../../providers/match_provider.dart';
import '../../models/match.dart';
import 'match_rotation_screen.dart';
import '../../database/match_set_state_repository.dart';
import '../../database/match_game_state_repository.dart';
import '../../providers/match_player_provider.dart';
import '../../database/match_substitution_state_repository.dart';
import '../../database/match_repository.dart';
import '../../database/match_point_undo_state_repository.dart';
import '../../database/match_set_participation_repository.dart';
import '../../services/match_excel_export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class GameScreen extends StatefulWidget {
  final int matchId;
  final int setNumber;
  final bool gcsServing;
  final int gcsSets;
  final int opponentSets;
  final bool firstServer;


  const GameScreen({
    super.key,
    required this.matchId,
    required this.setNumber,
    required this.gcsServing,
    required this.gcsSets,
    required this.opponentSets,
    required this.firstServer,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {

  final MatchSetStateRepository _matchSetStateRepository =
  MatchSetStateRepository();

  final MatchGameStateRepository _matchGameStateRepository =
  MatchGameStateRepository();

  final MatchSubstitutionStateRepository _matchSubstitutionStateRepository =
  MatchSubstitutionStateRepository();

  final MatchRepository _matchRepository =
  MatchRepository();

  final MatchPointUndoStateRepository
  _matchPointUndoStateRepository =
  MatchPointUndoStateRepository();

  final MatchSetParticipationRepository
  _matchSetParticipationRepository =
  MatchSetParticipationRepository();

  final MatchExcelExportService
  _matchExcelExportService =
  MatchExcelExportService();

  List<Player> lineup = [];
  List<Player> liberos = [];
  List<Player> squadPlayers = [];

  final Map<int, Set<int>> liberoAssociations = {};

  int? activeLiberoId;
  int? activeLiberoReplacedPlayerId;

  int substitutionsUsed = 0;
  final Map<int, int> substitutionPairs = {};
  final Set<int> completedSubstitutionPairs = {};

  Match? match;
  bool loading = true;

  int gcsScore = 0;
  int opponentScore = 0;

  int gcsSets = 0;
  int opponentSets = 0;

  late int currentSet;
  late bool gcsServing;
  late int currentRallyId;

  bool gameFinished = false;

  final List<Map<String, dynamic>> pointUndoHistory = [];

  @override
  void initState() {
    super.initState();

    currentSet = widget.setNumber;
    gcsServing = widget.gcsServing;
    currentRallyId = 1;

    gcsSets = widget.gcsSets;
    opponentSets = widget.opponentSets;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadLineup();
    });
  }

  Future<void> loadLineup() async {

    final lineupProvider = context.read<MatchLineupProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final matchProvider = context.read<MatchProvider>();
    final liberoProvider = context.read<MatchLiberoProvider>();
    final matchEventProvider = context.read<MatchEventProvider>();
    final matchPlayerProvider = context.read<MatchPlayerProvider>();

    await playerProvider.loadPlayers();

    match = matchProvider.matches.firstWhere(
          (m) => m.id == widget.matchId,
    );

    gameFinished = match!.finished;

    await lineupProvider.loadLineup(
      widget.matchId,
      currentSet,
    );

    await liberoProvider.loadLiberos(widget.matchId);

    await matchEventProvider.loadEvents(widget.matchId);

    final squadIds = await matchPlayerProvider.getSquad(widget.matchId);

    squadPlayers = squadIds.map((playerId) {
      return playerProvider.players.firstWhere(
            (player) => player.id == playerId,
      );
    }).toList();

    lineupProvider.currentLineup.sort(
          (a, b) => a.position.compareTo(b.position),
    );

    lineup = lineupProvider.currentLineup.map((item) {

      return playerProvider.players.firstWhere(
            (player) => player.id == item.playerId,
      );

    }).toList();

    await markCurrentLineupInGame();

    liberos = liberoProvider.currentLiberos.map((item) {

      return playerProvider.players.firstWhere(
            (player) => player.id == item.playerId,
      );

    }).toList();

    await restoreGameState();
    await restoreSubstitutionState();
    await restoreLiberoState();
    await restorePointUndoHistory();

    await saveGameState();

    if (!mounted) return;

    setState(() {
      loading = false;
    });

  }

  Future<void> restoreLiberoState() async {
    final state = await _matchSetStateRepository.getState(
      widget.matchId,
      currentSet,
    );

    if (state == null) return;

    final liberoId = state['activeLiberoId'] as int?;
    final replacedPlayerId = state['replacedPlayerId'] as int?;

    if (liberoId == null || replacedPlayerId == null) {
      return;
    }

    final liberoIndex = liberos.indexWhere(
          (player) => player.id == liberoId,
    );

    final playerIndex = lineup.indexWhere(
          (player) => player.id == replacedPlayerId,
    );

    if (liberoIndex == -1 || playerIndex == -1) {
      return;
    }

    lineup[playerIndex] = liberos[liberoIndex];

    activeLiberoId = liberoId;
    activeLiberoReplacedPlayerId = replacedPlayerId;
  }

  Future<void> restoreGameState() async {
    final state = await _matchGameStateRepository.getState(
      widget.matchId,
    );

    if (state == null) return;

    final savedSet = state['currentSet'] as int?;

    if (savedSet != currentSet) return;

    gcsScore = state['gcsScore'] as int? ?? 0;
    opponentScore = state['opponentScore'] as int? ?? 0;

    gcsSets = state['gcsSets'] as int? ?? gcsSets;
    opponentSets =
        state['opponentSets'] as int? ?? opponentSets;

    gcsServing =
        (state['gcsServing'] as int? ?? 0) == 1;

    currentRallyId =
        state['currentRallyId'] as int? ?? 1;
  }

  Future<void> restoreSubstitutionState() async {
    final savedPairs =
    await _matchSubstitutionStateRepository.getByMatchAndSet(
      widget.matchId,
      currentSet,
    );

    substitutionPairs.clear();
    completedSubstitutionPairs.clear();
    substitutionsUsed = 0;

    for (final row in savedPairs) {
      final starterId = row['starterId'] as int;
      final substituteId = row['substituteId'] as int;
      final completed =
          (row['completed'] as int? ?? 0) == 1;

      substitutionPairs[starterId] = substituteId;

      if (completed) {
        completedSubstitutionPairs.add(starterId);

        substitutionsUsed += 2;
      } else {
        substitutionsUsed += 1;
      }
    }
  }

  Future<void> saveGameState() async {
    await _matchGameStateRepository.saveState(
      matchId: widget.matchId,
      currentSet: currentSet,
      gcsScore: gcsScore,
      opponentScore: opponentScore,
      gcsSets: gcsSets,
      opponentSets: opponentSets,
      gcsServing: gcsServing,
      currentRallyId: currentRallyId,
    );
  }

  Future<void> markCurrentLineupInGame() async {
    for (final player in lineup) {
      final playerId = player.id;

      if (playerId == null) continue;

      await _matchSetParticipationRepository.markPlayerInGame(
        matchId: widget.matchId,
        setNumber: currentSet,
        playerId: playerId,
      );
    }
  }

  Future<int> savePointUndoState({
    int? eventId,
    required String team,
    required bool previousGcsServing,
    required List<Player> previousLineup,
    required int? previousActiveLiberoId,
    required int? previousReplacedPlayerId,
    required int previousRallyId,
  }) async {
    return await _matchPointUndoStateRepository.saveState(
      eventId: eventId,
      matchId: widget.matchId,
      setNumber: currentSet,
      team: team,
      previousGcsServing: previousGcsServing,
      lineupPlayerIds: previousLineup
          .map((player) => player.id!)
          .toList(),
      activeLiberoId: previousActiveLiberoId,
      replacedPlayerId: previousReplacedPlayerId,
      previousRallyId: previousRallyId,
    );
  }

  Future<void> restorePointUndoHistory() async {
    final players = context.read<PlayerProvider>().players;

    final savedStates =
    await _matchPointUndoStateRepository
        .getByMatchAndSet(
      widget.matchId,
      currentSet,
    );

    pointUndoHistory.clear();

    for (final state in savedStates) {
      final lineupIds =
      _matchPointUndoStateRepository.decodeLineup(
        state['lineup'] as String,
      );

      final savedLineup = lineupIds.map((playerId) {
        return players.firstWhere(
              (player) => player.id == playerId,
        );
      }).toList();

      pointUndoHistory.add({
        'undoStateId': state['id'],
        'team': state['team'],
        'sourceEventId': state['eventId'],
        'previousGcsServing':
        state['previousGcsServing'] == 1,
        'lineup': savedLineup,
        'activeLiberoId':
        state['activeLiberoId'] as int?,
        'activeLiberoReplacedPlayerId':
        state['replacedPlayerId'] as int?,
        'previousRallyId':
        state['previousRallyId'] as int? ?? 1,
      });
    }
  }

  void enterLibero({
    required int liberoId,
    required int playerId,
  }) {
    // Só pode haver um líbero em campo.
    if (activeLiberoId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Já existe um líbero em campo.",
          ),
        ),
      );
      return;
    }

    // O líbero passa a estar associado à jogadora
    // que estava naquela posição.
    liberoAssociations.putIfAbsent(
      liberoId,
          () => <int>{},
    );

    liberoAssociations[liberoId]!.add(playerId);

    setState(() {
      activeLiberoId = liberoId;
    });
  }

  Future<void> enterLiberoAtPosition({
    required int liberoId,
    required int position,
  }) async {
    // Só pode haver um líbero em campo.
    if (activeLiberoId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Já existe um líbero em campo."),
        ),
      );
      return;
    }

    // Só pode entrar nas posições de trás.
    if (position != 1 && position != 5 && position != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "O líbero só pode entrar em P1, P5 ou P6.",
          ),
        ),
      );
      return;
    }

    final index = position - 1;

    final playerId = lineup[index].id!;

    // Guarda a jogadora que o líbero substituiu.
    liberoAssociations.putIfAbsent(
      liberoId,
          () => <int>{},
    );

    liberoAssociations[liberoId]!.add(playerId);

    final libero = liberos.firstWhere(
          (player) => player.id == liberoId,
    );

    setState(() {
      lineup[index] = libero;
      activeLiberoId = liberoId;
      activeLiberoReplacedPlayerId = playerId;
    });

    await _matchSetParticipationRepository.markPlayerInGame(
      matchId: widget.matchId,
      setNumber: currentSet,
      playerId: liberoId,
    );

    await _matchSetStateRepository.saveState(
      matchId: widget.matchId,
      setNumber: currentSet,
      activeLiberoId: liberoId,
      replacedPlayerId: playerId,
    );
  }

  Future<void> switchActiveLibero(int newLiberoId) async {
    if (activeLiberoId == null ||
        activeLiberoReplacedPlayerId == null) {
      return;
    }

    // Não permite "trocar" pelo mesmo líbero.
    if (newLiberoId == activeLiberoId) {
      return;
    }

    final liberoIndex = lineup.indexWhere(
          (player) => player.id == activeLiberoId,
    );

    if (liberoIndex == -1) return;

    final newLibero = liberos.firstWhere(
          (player) => player.id == newLiberoId,
    );

    final replacedPlayerId =
    activeLiberoReplacedPlayerId!;

    liberoAssociations.putIfAbsent(
      newLiberoId,
          () => <int>{},
    );

    liberoAssociations[newLiberoId]!.add(
      replacedPlayerId,
    );

    setState(() {
      lineup[liberoIndex] = newLibero;
      activeLiberoId = newLiberoId;
    });

    await _matchSetParticipationRepository.markPlayerInGame(
      matchId: widget.matchId,
      setNumber: currentSet,
      playerId: newLiberoId,
    );

    await _matchSetStateRepository.saveState(
      matchId: widget.matchId,
      setNumber: currentSet,
      activeLiberoId: newLiberoId,
      replacedPlayerId: replacedPlayerId,
    );
  }

  Future<void> exitActiveLibero() async {
    if (activeLiberoId == null ||
        activeLiberoReplacedPlayerId == null) {
      return;
    }

    final liberoIndex = lineup.indexWhere(
          (player) => player.id == activeLiberoId,
    );

    if (liberoIndex == -1) return;

    final playerProvider =
    context.read<PlayerProvider>();

    final returningPlayer =
    playerProvider.players.firstWhere(
          (player) =>
      player.id ==
          activeLiberoReplacedPlayerId,
    );

    setState(() {
      lineup[liberoIndex] = returningPlayer;

      activeLiberoId = null;
      activeLiberoReplacedPlayerId = null;
    });

    await _matchSetStateRepository.clearState(
      widget.matchId,
      currentSet,
    );
  }

  Future<void> substitutePlayer({
    required int outgoingPlayerId,
    required int incomingPlayerId,
  }) async {
    if (substitutionsUsed >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Já foram utilizadas as 6 substituições deste set.",
          ),
        ),
      );
      return;
    }

    if (liberos.any(
          (player) => player.id == incomingPlayerId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "O líbero não conta como substituição.",
          ),
        ),
      );
      return;
    }

    if (outgoingPlayerId == activeLiberoId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Primeiro tem de sair o líbero.",
          ),
        ),
      );
      return;
    }

    final outgoingIndex = lineup.indexWhere(
          (player) => player.id == outgoingPlayerId,
    );

    if (outgoingIndex == -1) return;

    if (lineup.any(
          (player) => player.id == incomingPlayerId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Essa jogadora já está em campo.",
          ),
        ),
      );
      return;
    }

    final playerProvider =
    context.read<PlayerProvider>();

    final incomingPlayer =
    playerProvider.players.firstWhere(
          (player) => player.id == incomingPlayerId,
    );

    int? starterId;

    for (final pair in substitutionPairs.entries) {
      if (pair.value == outgoingPlayerId) {
        starterId = pair.key;
        break;
      }
    }

    if (starterId != null) {
      if (incomingPlayerId != starterId) {
        final starter =
        playerProvider.players.firstWhere(
              (player) => player.id == starterId,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${lineup[outgoingIndex].name} só pode sair por ${starter.name}.",
            ),
          ),
        );
        return;
      }

      setState(() {
        lineup[outgoingIndex] = incomingPlayer;

        substitutionsUsed++;

        completedSubstitutionPairs.add(
          starterId!,
        );
      });

      await _matchSubstitutionStateRepository.markCompleted(
        matchId: widget.matchId,
        setNumber: currentSet,
        starterId: starterId,
      );

      await _saveCurrentLineupAfterSubstitution();

      return;
    }

    if (completedSubstitutionPairs.contains(
      outgoingPlayerId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Esta jogadora já completou a sua substituição neste set.",
          ),
        ),
      );
      return;
    }

    final incomingAlreadyUsed =
    substitutionPairs.entries.any(
          (pair) =>
      pair.key == incomingPlayerId ||
          pair.value == incomingPlayerId,
    );

    if (incomingAlreadyUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Esta jogadora já pertence a outra substituição neste set.",
          ),
        ),
      );
      return;
    }

    substitutionPairs[outgoingPlayerId] =
        incomingPlayerId;

    setState(() {
      lineup[outgoingIndex] = incomingPlayer;
      substitutionsUsed++;
    });

    await _matchSetParticipationRepository.markPlayerInGame(
      matchId: widget.matchId,
      setNumber: currentSet,
      playerId: incomingPlayerId,
    );

    await _matchSubstitutionStateRepository.savePair(
      matchId: widget.matchId,
      setNumber: currentSet,
      starterId: outgoingPlayerId,
      substituteId: incomingPlayerId,
    );

    await _saveCurrentLineupAfterSubstitution();
  }

  Future<void> _saveCurrentLineupAfterSubstitution() async {
    final lineupToSave = <int, int>{};

    for (int i = 0; i < lineup.length; i++) {
      int playerId = lineup[i].id!;

      if (activeLiberoId != null &&
          activeLiberoReplacedPlayerId != null &&
          playerId == activeLiberoId) {
        playerId = activeLiberoReplacedPlayerId!;
      }

      lineupToSave[i + 1] = playerId;
    }

    await context
        .read<MatchLineupProvider>()
        .saveLineup(
      widget.matchId,
      currentSet,
      lineupToSave,
    );
  }

  Future<void> rotateLineup() async {
    final playerProvider = context.read<PlayerProvider>();
    final lineupProvider = context.read<MatchLineupProvider>();

    bool liberoExitedAutomatically = false;

    setState(() {
      final first = lineup.removeAt(0);
      lineup.add(first);

      if (activeLiberoId != null &&
          activeLiberoReplacedPlayerId != null &&
          lineup[3].id == activeLiberoId) {

        final returningPlayer =
        playerProvider.players.firstWhere(
              (player) =>
          player.id == activeLiberoReplacedPlayerId,
        );

        lineup[3] = returningPlayer;

        activeLiberoId = null;
        activeLiberoReplacedPlayerId = null;

        liberoExitedAutomatically = true;
      }
    });

    if (liberoExitedAutomatically) {
      await _matchSetStateRepository.clearState(
        widget.matchId,
        currentSet,
      );
    }

    for (int i = 0; i < lineup.length; i++) {

      int playerIdToSave = lineup[i].id!;

      if (activeLiberoId != null &&
          activeLiberoReplacedPlayerId != null &&
          lineup[i].id == activeLiberoId) {

        playerIdToSave =
        activeLiberoReplacedPlayerId!;
      }

      await lineupProvider.updatePosition(
        widget.matchId,
        currentSet,
        playerIdToSave,
        i + 1,
      );
    }
  }

  bool isSetFinished() {
    final target = currentSet == 5 ? 15 : 25;

    if (gcsScore >= target || opponentScore >= target) {
      return (gcsScore - opponentScore).abs() >= 2;
    }

    return false;
  }

  Future<void> gcsPoint({
    int? sourceEventId,
  }) async {
    if (gameFinished) return;

    final causedRotation = !gcsServing;

    final undoStateId = await savePointUndoState(
      eventId: sourceEventId,
      team: 'gcs',
      previousGcsServing: gcsServing,
      previousLineup: List<Player>.from(lineup),
      previousActiveLiberoId: activeLiberoId,
      previousReplacedPlayerId:
      activeLiberoReplacedPlayerId,
      previousRallyId: currentRallyId,
    );

    pointUndoHistory.add({
      'undoStateId': undoStateId,
      'team': 'gcs',
      'sourceEventId': sourceEventId,
      'causedRotation': causedRotation,
      'previousGcsServing': gcsServing,
      'lineup': List<Player>.from(lineup),
      'activeLiberoId': activeLiberoId,
      'activeLiberoReplacedPlayerId':
      activeLiberoReplacedPlayerId,
      'previousRallyId': currentRallyId,
    });

    setState(() {
      gcsScore++;
      currentRallyId++;

      if (causedRotation) {
        gcsServing = true;
      }
    });

    if (causedRotation) {
      await rotateLineup();
    }

    await saveGameState();

    final target = currentSet == 5 ? 15 : 25;

    if (gcsScore >= target &&
        gcsScore - opponentScore >= 2) {
      confirmarFimDoSet(true);
    }
  }

  Future<void> opponentPoint({
    int? sourceEventId,
  }) async {
    if (gameFinished) return;

    final undoStateId = await savePointUndoState(
      eventId: sourceEventId,
      team: 'opponent',
      previousGcsServing: gcsServing,
      previousLineup: List<Player>.from(lineup),
      previousActiveLiberoId: activeLiberoId,
      previousReplacedPlayerId:
      activeLiberoReplacedPlayerId,
      previousRallyId: currentRallyId,
    );

    pointUndoHistory.add({
      'undoStateId': undoStateId,
      'team': 'opponent',
      'sourceEventId': sourceEventId,
      'previousGcsServing': gcsServing,
      'lineup': List<Player>.from(lineup),
      'activeLiberoId': activeLiberoId,
      'activeLiberoReplacedPlayerId':
      activeLiberoReplacedPlayerId,
      'previousRallyId': currentRallyId,
    });

    setState(() {
      opponentScore++;
      gcsServing = false;
      currentRallyId++;
    });

    await saveGameState();

    final target = currentSet == 5 ? 15 : 25;

    if (opponentScore >= target &&
        opponentScore - gcsScore >= 2) {
      confirmarFimDoSet(false);
    }
  }

  Future<bool> undoLastPoint(
      String team, {
        int? sourceEventId,
      }) async {
    if (pointUndoHistory.isEmpty) {
      return false;
    }

    final undoData = pointUndoHistory.last;

    if (undoData['team'] != team) {
      return false;
    }

    if (sourceEventId != null &&
        undoData['sourceEventId'] != sourceEventId) {
      return false;
    }

    pointUndoHistory.removeLast();

    final undoStateId =
    undoData['undoStateId'] as int?;

    if (undoStateId != null) {
      await _matchPointUndoStateRepository
          .deleteById(
        undoStateId,
      );
    } else if (sourceEventId != null) {
      await _matchPointUndoStateRepository
          .deleteByEventId(
        sourceEventId,
      );
    }

    setState(() {
      if (team == 'gcs') {
        gcsScore = max(0, gcsScore - 1);
      } else {
        opponentScore = max(
          0,
          opponentScore - 1,
        );
      }

      lineup = List<Player>.from(
        undoData['lineup'] as List<Player>,
      );

      gcsServing =
      undoData['previousGcsServing'] as bool;

      activeLiberoId =
      undoData['activeLiberoId'] as int?;

      activeLiberoReplacedPlayerId =
      undoData['activeLiberoReplacedPlayerId']
      as int?;

      currentRallyId =
      undoData['previousRallyId']
      as int? ?? 1;

    });

    await _saveCurrentLineupAfterSubstitution();

    if (activeLiberoId != null &&
        activeLiberoReplacedPlayerId != null) {
      await _matchSetStateRepository.saveState(
        matchId: widget.matchId,
        setNumber: currentSet,
        activeLiberoId: activeLiberoId!,
        replacedPlayerId:
        activeLiberoReplacedPlayerId!,
      );
    } else {
      await _matchSetStateRepository.clearState(
        widget.matchId,
        currentSet,
      );
    }

    await saveGameState();

    return true;
  }

  bool isDistributionError(String result) {
    if (result.trim() == 'Erro') {
      return true;
    }

    final separatorIndex = result.indexOf(' | ');

    if (separatorIndex == -1) {
      return false;
    }

    final typesText = result.substring(separatorIndex + 3);
    final colonIndex = typesText.indexOf(':');

    final selectedTypes = (colonIndex >= 0
        ? typesText.substring(colonIndex + 1)
        : typesText)
        .split(',')
        .map((type) => type.trim());

    return selectedTypes.contains('Erro');
  }

  Future<void> processResult(
      String action,
      String result, {
        int? sourceEventId,
      }) async {
    switch (action) {
      case "Serviço":
        if (result == "Ace") {
          await gcsPoint(
            sourceEventId: sourceEventId,
          );
        } else if (result == "Erro") {
          await opponentPoint(
            sourceEventId: sourceEventId,
          );
        }
        break;

      case "Ataque":
        if (result == "Ponto") {
          await gcsPoint(
            sourceEventId: sourceEventId,
          );
        } else if (
        result == "Erro" ||
            result == "Blocado") {
          await opponentPoint(
            sourceEventId: sourceEventId,
          );
        }
        break;

      case "Receção":
        if (result == "Erro") {
          await opponentPoint(
            sourceEventId: sourceEventId,
          );
        }
        break;

      case "Bloco":
        if (result == "Ponto") {
          await gcsPoint(
            sourceEventId: sourceEventId,
          );
        } else if (result == "Erro") {
          await opponentPoint(
            sourceEventId: sourceEventId,
          );
        }
        break;

      case "Distribuição":
        if (isDistributionError(result)) {
          await opponentPoint(
            sourceEventId: sourceEventId,
          );
        }
        break;

      case "Defesa":
        if (result == "Erro") {
          await opponentPoint(
            sourceEventId: sourceEventId,
          );
        }
        break;
    }
  }

  void checkEndSet() {
    final target = (match!.sets == 5 && currentSet == 5) ? 15 : 25;

    if (gcsScore >= target &&
        gcsScore - opponentScore >= 2) {
      endSet(true);
    }

    if (opponentScore >= target &&
        opponentScore - gcsScore >= 2) {
      endSet(false);
    }
  }

  Future<bool> escolherServidor() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Novo sorteio"),
          content: const Text(
            "Quem começa o serviço neste set?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("GCS"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(match!.opponent),
            ),
          ],
        );
      },
    );

    return resultado ?? match!.firstServer;
  }

  Future<void> exportCurrentMatchToExcel() async {
    if (match == null) return;

    debugPrint('É WEB: $kIsWeb');

    final events = context
        .read<MatchEventProvider>()
        .events
        .where(
          (event) => event.matchId == widget.matchId,
    )
        .toList();

    final excelBytes =
    await _matchExcelExportService.exportMatch(
      match: match!,
      players: squadPlayers,
      events: events,
      finalGcsSets: gcsSets,
      finalOpponentSets: opponentSets,
    );

    if (kIsWeb) {
      _matchExcelExportService.downloadExcelWeb(excelBytes);
      return;
    }

    await shareExcelFile();
  }

  Future<void> shareExcelFile() async {
    final excelFile =
    await _matchExcelExportService.getExcelFile();

    if (!await excelFile.exists()) {
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(excelFile.path),
        ],
        subject: 'GCS - Estatísticas 2026/2027',
      ),
    );
  }

  Future<void> confirmarFimDoSet(bool gcsWon) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Terminar set?"),
          content: Text(
            "Resultado atual:\n\n"
                "GCS $gcsScore - $opponentScore ${match!.opponent}\n\n"
                "Confirma que pretende encerrar este set?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Não"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Sim, terminar"),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await endSet(gcsWon);
    }
  }

  Future<void> endSet(bool gcsWon) async {

    final matchParticipationStats =
    await _matchSetParticipationRepository
        .getMatchParticipationStats(
      matchId: widget.matchId,
    );

    debugPrint('===== PARTICIPAÇÃO JOGO =====');

    for (final entry in matchParticipationStats.entries) {
      final player = squadPlayers.firstWhere(
            (player) => player.id == entry.key,
      );

      debugPrint(
        '${player.name} | '
            'Pontos jogados: ${entry.value['pointsPlayed']} | '
            'Pontos fora: ${entry.value['pointsOut']}',
      );
    }

    if (gcsWon) {
      gcsSets++;
    } else {
      opponentSets++;
    }

    final neededSets = match!.sets == 5 ? 3 : 2;

    final jogoTerminou =
        gcsSets >= neededSets ||
            opponentSets >= neededSets;

    if (jogoTerminou) {

      // =========================
      // JOGO OFICIAL
      // =========================

      if (match!.official == true) {

        setState(() {
          gameFinished = true;
        });

        await _matchRepository.finishMatch(
          matchId: widget.matchId,
          gcsSets: gcsSets,
          opponentSets: opponentSets,
        );

        await Future.delayed(
          const Duration(milliseconds: 100),
        );

        if (!mounted) return;

        final gcsWon = gcsSets > opponentSets;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              title: const Text("Fim do jogo"),
              content: Text(
                gcsWon
                    ? "GCS venceu $gcsSets-$opponentSets"
                    : "${match!.opponent} venceu "
                    "$opponentSets-$gcsSets",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Fechar"),
                ),
              ],
            );
          },
        );

        if (!mounted) return;

        Navigator.pop(context);

        return;
      }

      // =========================
      // JOGO AMIGÁVEL
      // =========================

      final continuar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          final gcsWon = gcsSets > opponentSets;

          return AlertDialog(
            title: const Text("Continuar jogo?"),
            content: Text(
              gcsWon
                  ? "GCS venceu $gcsSets-$opponentSets.\n\n"
                  "Pretende terminar o jogo ou fazer mais um set?"
                  : "${match!.opponent} venceu "
                  "$opponentSets-$gcsSets.\n\n"
                  "Pretende terminar o jogo ou fazer mais um set?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text("Terminar jogo"),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("Fazer mais um set"),
              ),
            ],
          );
        },
      );

      if (continuar != true) {

        setState(() {
          gameFinished = true;
        });

        await _matchRepository.finishMatch(
          matchId: widget.matchId,
          gcsSets: gcsSets,
          opponentSets: opponentSets,
        );

        await Future.delayed(
          const Duration(milliseconds: 100),
        );

        if (!mounted) return;

        final gcsWon = gcsSets > opponentSets;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              title: const Text("Fim do jogo"),
              content: Text(
                gcsWon
                    ? "GCS venceu $gcsSets-$opponentSets"
                    : "${match!.opponent} venceu "
                    "$opponentSets-$gcsSets",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Fechar"),
                ),
              ],
            );
          },
        );

        if (!mounted) return;

        Navigator.pop(context);

        return;
      }

      // Amigável + escolheu continuar
      // → segue para o próximo set
    }

    final nextSet = currentSet + 1;

    bool nextGcsServing;

    // =========================
    // SERVIÇO DO PRÓXIMO SET
    // =========================

    if (nextSet == 5) {
      // 5.º set → novo sorteio
      nextGcsServing = await escolherServidor();
    } else if (nextSet.isOdd) {
      // Sets 1 e 3 → mesmo serviço do Set 1
      nextGcsServing = widget.firstServer;
    } else {
      // Sets 2 e 4 → contrário do Set 1
      nextGcsServing = !widget.firstServer;
    }

    if (!mounted) return;

    await _matchGameStateRepository.saveState(
      matchId: widget.matchId,
      currentSet: nextSet,
      gcsScore: 0,
      opponentScore: 0,
      gcsSets: gcsSets,
      opponentSets: opponentSets,
      gcsServing: nextGcsServing,
      currentRallyId: 1,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchRotationScreen(
          matchId: widget.matchId,
          setterId: 0,
          oppositeId: 0,
          middleIds: const [],
          outsideIds: const [],
          setNumber: nextSet,
          gcsServing: nextGcsServing,
          firstServer: widget.firstServer,
          gcsSets: gcsSets,
          opponentSets: opponentSets,
        ),
      ),
    );
  }



  Future<String?> showDistributionSheet() async {
    const zones = [
      'Entrada',
      'Central',
      'Oposto',
      'Pipe',
    ];

    const distributionTypes = [
      'Perfeita',
      'Interior',
      'Aberta',
      'Baixa',
      'Alta',
      'Cima da Rede',
      'Afastada da Rede',
      'Erro',
    ];

    String? selectedZone;
    String? selectedPipeZone;
    final selectedTypes = <String>{};

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final zoneIsReady =
                selectedZone != null &&
                    (selectedZone != 'Pipe' ||
                        selectedPipeZone != null);

            final buttonWidth =
                (MediaQuery.of(sheetContext).size.width - 48) / 2;

            Widget optionButton({
              required String label,
              required bool selected,
              required VoidCallback? onPressed,
            }) {
              return SizedBox(
                width: buttonWidth,
                height: 48,
                child: selected
                    ? FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                  ),
                )
                    : OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return SafeArea(
              child: SizedBox(
                height:
                MediaQuery.of(sheetContext).size.height * 0.85,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Distribuição',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            'Zona de ataque',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: zones.map((zone) {
                              return optionButton(
                                label: zone,
                                selected: selectedZone == zone,
                                onPressed: () {
                                  setModalState(() {
                                    selectedZone = zone;

                                    if (zone != 'Pipe') {
                                      selectedPipeZone = null;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          if (selectedZone == 'Pipe') ...[
                            const SizedBox(height: 18),

                            const Text(
                              'Zona do Pipe',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['Zona 6', 'Zona 1'].map((zone) {
                                return optionButton(
                                  label: zone,
                                  selected: selectedPipeZone == zone,
                                  onPressed: () {
                                    setModalState(() {
                                      selectedPipeZone = zone;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],

                          if (zoneIsReady) ...[
                            const SizedBox(height: 22),

                            const Text(
                              'Tipo de distribuição',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              selectedTypes.contains('Perfeita') ||
                                  selectedTypes.contains('Erro')
                                  ? 'Opção exclusiva selecionada'
                                  : 'Seleciona até 3 opções',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: distributionTypes.map((type) {
                                final selected =
                                selectedTypes.contains(type);

                                final exclusive =
                                    type == 'Perfeita' || type == 'Erro';

                                final limitReached =
                                    selectedTypes.length >= 3 &&
                                        !selected &&
                                        !exclusive &&
                                        !selectedTypes.contains('Perfeita') &&
                                        !selectedTypes.contains('Erro');

                                return optionButton(
                                  label: type,
                                  selected: selected,
                                  onPressed: limitReached
                                      ? null
                                      : () {
                                    setModalState(() {
                                      if (selected) {
                                        selectedTypes.remove(type);
                                      } else if (exclusive) {
                                        selectedTypes
                                          ..clear()
                                          ..add(type);
                                      } else {
                                        selectedTypes.remove('Perfeita');
                                        selectedTypes.remove('Erro');

                                        if (selectedTypes.length < 3) {
                                          selectedTypes.add(type);
                                        }
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed:
                          zoneIsReady && selectedTypes.isNotEmpty
                              ? () {
                            final zoneLabel =
                            selectedZone == 'Pipe'
                                ? 'Pipe - $selectedPipeZone'
                                : selectedZone!;

                            final result =
                                'Zona de ataque: $zoneLabel | '
                                'Tipo de distribuição: '
                                '${selectedTypes.join(", ")}';

                            Navigator.pop(
                              sheetContext,
                              result,
                            );
                          }
                              : null,
                          child: const Text('Registar distribuição'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> resultOptionsForAction(
      String action,
      ) {
    switch (action) {
      case "Serviço":
        return [
          "Ace",
          "Positivo",
          "Fraco",
          "Erro",
        ];

      case "Ataque":
        return [
          "Ponto",
          "Continuação",
          "Blocado",
          "Passe/Manchete",
          "Erro",
        ];

      case "Receção":
        return [
          "Bola A",
          "Bola B",
          "Bola C",
          "Erro",
        ];

      case "Bloco":
        return [
          "Ponto",
          "Toque",
          "Erro",
        ];

      case "Defesa":
        return [
          "Excelente",
          "Positiva",
          "Continuação",
          "Erro",
        ];

      default:
        return [];
    }
  }

  Map<String, int> scoreEffectForResult(
      String action,
      String result,
      ) {
    int gcs = 0;
    int opponent = 0;

    switch (action) {
      case "Serviço":
        if (result == "Ace") {
          gcs = 1;
        } else if (result == "Erro") {
          opponent = 1;
        }
        break;

      case "Ataque":
        if (result == "Ponto") {
          gcs = 1;
        } else if (
        result == "Blocado" ||
            result == "Erro") {
          opponent = 1;
        }
        break;

      case "Receção":
        if (result == "Erro") {
          opponent = 1;
        }
        break;

      case "Bloco":
        if (result == "Ponto") {
          gcs = 1;
        } else if (result == "Erro") {
          opponent = 1;
        }
        break;

      case "Distribuição":
        if (result == "Erro") {
          opponent = 1;
        }
        break;

      case "Defesa":
        if (result == "Erro") {
          opponent = 1;
        }
        break;
    }

    return {
      "gcs": gcs,
      "opponent": opponent,
    };
  }

  Future<void> showEventHistory() async {
    await context
        .read<MatchEventProvider>()
        .loadEvents(widget.matchId);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer<MatchEventProvider>(
          builder: (context, eventProvider, _) {
            final events = eventProvider.events
                .where(
                  (event) => event.matchId == widget.matchId,
            )
                .toList()
                .reversed
                .toList();

            return SafeArea(
              child: SizedBox(
                height:
                MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Histórico de Ações",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    Expanded(
                      child: events.isEmpty
                          ? const Center(
                        child: Text(
                          "Ainda não existem ações registadas.",
                        ),
                      )
                          : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];

                          final players = context
                              .read<PlayerProvider>()
                              .players;

                          String playerName =
                              "Jogadora ${event.playerId}";

                          for (final player in players) {
                            if (player.id ==
                                event.playerId) {
                              playerName =
                              "#${player.number} ${player.name}";
                              break;
                            }
                          }

                          final canEdit =
                              event.setNumber == currentSet;

                          return ListTile(
                            title: Text(
                              "$playerName — ${event.action}",
                            ),
                            subtitle: Text(
                              "Set ${event.setNumber} • ${event.result}",
                            ),

                            onTap: !canEdit || event.id == null
                                ? null
                                : () async {
                              String? newResult;

                              if (event.action == 'Distribuição') {
                                newResult =
                                await showDistributionSheet();
                              } else {
                                final options =
                                resultOptionsForAction(
                                  event.action,
                                );

                                if (options.isEmpty) return;

                                newResult =
                                await showModalBottomSheet<String>(
                                  context: context,
                                  builder: (_) => ActionResultSheet(
                                    title: 'Alterar ${event.action}',
                                    options: options,
                                  ),
                                );
                              }

                              if (newResult == null ||
                                  newResult == event.result) {
                                return;
                              }

                              final oldEffect = scoreEffectForResult(
                                event.action,
                                event.result,
                              );

                              final newEffect = scoreEffectForResult(
                                event.action,
                                newResult,
                              );

                              if (event.setNumber == currentSet &&
                                  !gameFinished) {
                                final oldGcs = oldEffect["gcs"]!;
                                final oldOpponent =
                                oldEffect["opponent"]!;

                                final newGcs = newEffect["gcs"]!;
                                final newOpponent =
                                newEffect["opponent"]!;

                                // Primeiro desfaz o efeito antigo.
                                if (oldGcs == 1) {
                                  final undone = await undoLastPoint(
                                    'gcs',
                                    sourceEventId: event.id!,
                                  );

                                  if (!undone) return;
                                } else if (oldOpponent == 1) {
                                  final undone = await undoLastPoint(
                                    'opponent',
                                    sourceEventId: event.id!,
                                  );

                                  if (!undone) return;
                                }

                                // Depois aplica o novo efeito.
                                if (newGcs == 1) {
                                  await gcsPoint(
                                    sourceEventId: event.id!,
                                  );
                                } else if (newOpponent == 1) {
                                  await opponentPoint(
                                    sourceEventId: event.id!,
                                  );
                                }
                              }

                              if (!context.mounted) return;

                              await context
                                  .read<MatchEventProvider>()
                                  .updateEventResult(
                                event.id!,
                                widget.matchId,
                                newResult,
                              );
                            },

                            trailing: canEdit
                                ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                              ),
                              onPressed: event.id == null
                                  ? null
                                  : () async {
                                final effect = scoreEffectForResult(
                                  event.action,
                                  event.result,
                                );

                                if (event.setNumber == currentSet &&
                                    !gameFinished) {
                                  final gcsEffect = effect["gcs"]!;
                                  final opponentEffect =
                                  effect["opponent"]!;

                                  if (gcsEffect == 1) {
                                    final undone = await undoLastPoint(
                                      'gcs',
                                      sourceEventId: event.id!,
                                    );

                                    if (!undone) return;
                                  } else if (opponentEffect == 1) {
                                    final undone = await undoLastPoint(
                                      'opponent',
                                      sourceEventId: event.id!,
                                    );

                                    if (!undone) return;
                                  }
                                }

                                if (!context.mounted) return;

                                await context
                                    .read<MatchEventProvider>()
                                    .deleteEvent(
                                  event.id!,
                                  widget.matchId,
                                );
                              },
                            )
                                : const Icon(
                              Icons.lock_outline,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || match == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          match!.home
              ? "GCS vs ${match!.opponent}"
              : "${match!.opponent} vs GCS",
        ),
        actions: [
          IconButton(
            tooltip: "Histórico de Ações",
            icon: const Icon(Icons.history),
            onPressed: showEventHistory,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    Text(
                      "Set $currentSet",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      gcsServing
                          ? "🏐 Serviço: GCS"
                          : "🏐 Serviço: ${match!.opponent}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [

                        Column(
                          children: [

                            const Text(
                              "GCS",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            Text(
                              "$gcsScore",
                              style: const TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          ],
                        ),

                        const Text(
                          "-",
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Column(
                          children: [

                            Text(
                              match!.opponent,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            Text(
                              "$opponentScore",
                              style: const TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          ],
                        ),

                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [

                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Ponto GCS"),
                            onPressed: gcsPoint,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Ponto Adv."),
                            onPressed: opponentPoint,
                          ),
                        ),

                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              if (gcsScore <= 0) return;

                              final undone = await undoLastPoint(
                                'gcs',
                              );

                              if (!undone) {
                                setState(() {
                                  gcsScore--;
                                });

                                await saveGameState();
                              }
                            },
                            child: const Text("- GCS"),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              if (opponentScore <= 0) return;

                              final undone = await undoLastPoint(
                                'opponent',
                              );

                              if (!undone) {
                                setState(() {
                                  opponentScore--;
                                });

                                await saveGameState();
                              }
                            },
                            child: const Text("- Adv."),
                          ),
                        ),

                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Column(
                children: [

                  const Text(
                    "REDE",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [

                      Expanded(
                        child: playerButton(
                          context,
                          widget.matchId,
                          lineup[3].id!,
                          lineup[3].number.toString(),
                          lineup[3].name,
                          match!.opponent,
                          gcsServing,
                          4
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: playerButton(
                          context,
                          widget.matchId,
                          lineup[2].id!,
                          lineup[2].number.toString(),
                          lineup[2].name,
                          match!.opponent,
                          gcsServing,
                          3
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: playerButton(
                          context,
                          widget.matchId,
                          lineup[1].id!,
                          lineup[1].number.toString(),
                          lineup[1].name,
                          match!.opponent,
                          gcsServing,
                          2
                        ),
                      ),

                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [

                      Expanded(
                        child: playerButton(
                          context,
                          widget.matchId,
                          lineup[4].id!,
                          lineup[4].number.toString(),
                          lineup[4].name,
                          match!.opponent,
                          gcsServing,
                          5
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: playerButton(
                          context,
                          widget.matchId,
                          lineup[5].id!,
                          lineup[5].number.toString(),
                          lineup[5].name,
                          match!.opponent,
                          gcsServing,
                          6
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: playerButton(
                          context,
                          widget.matchId,
                          lineup[0].id!,
                          lineup[0].number.toString(),
                          lineup[0].name,
                          match!.opponent,
                          gcsServing,
                          1
                        ),
                      ),

                    ],
                  ),

                  const SizedBox(height: 30),

                  if (liberos.isNotEmpty)
                    Column(
                      children: [

                        const Divider(),

                        const Text(
                          "🥎 Líberos",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          children: liberos.map((player) {

                            return Chip(
                              avatar: CircleAvatar(
                                child: Text(player.number.toString()),
                              ),
                              label: Text(player.name),
                            );

                          }).toList(),
                        ),

                      ],
                    ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget playerButton(
      BuildContext context,
      int matchId,
      int playerId,
      String number,
      String name,
      String opponent,
      bool gcsServing,
      int position,
      ) {
    return Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () {

            showModalBottomSheet(
              context: context,
              builder: (_) {

                return SafeArea(
                  child: Wrap(
                    children: [

                      ListTile(
                        title: Text(
                          "$number - $name",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Divider(),

                      if (gcsServing && position == 1)
                      ListTile(
                        leading: const Icon(Icons.sports_volleyball),
                        title: Text(
                          gcsServing
                              ? "🏐 Serviço: GCS"
                              : "🏐 Serviço: $opponent",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {

                          Navigator.pop(context);

                          final result = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => const ActionResultSheet(
                              title: "Resultado do Serviço",
                              options: [
                                "Ace",
                                "Positivo",
                                "Fraco",
                                "Erro",
                              ],
                            ),
                          );

                          if (result != null) {

                            final eventId =
                            await context.read<MatchEventProvider>().addEvent(
                              MatchEvent(
                                matchId: matchId,
                                playerId: playerId,
                                action: "Serviço",
                                result: result,
                                setNumber: currentSet,
                                rallyId: currentRallyId,
                              ),
                            );

                            await processResult(
                              "Serviço",
                              result,
                              sourceEventId: eventId,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name → Serviço → $result"),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                        },
                      ),

                      ListTile(
                        leading: Icon(Icons.flash_on),
                        title: const Text("Ataque"),
                        onTap: () async {

                          Navigator.pop(context);

                          final result = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => const ActionResultSheet(
                              title: "Resultado do Ataque",
                              options: [
                                "Ponto",
                                "Continuação",
                                "Blocado",
                                "Passe/Manchete",
                                "Erro",
                              ],
                            ),
                          );

                          if (result != null) {

                            final eventId =
                            await context.read<MatchEventProvider>().addEvent(
                              MatchEvent(
                                matchId: matchId,
                                playerId: playerId,
                                action: "Ataque",
                                result: result,
                                setNumber: currentSet,
                                rallyId: currentRallyId,
                              ),
                            );

                            await processResult(
                              "Ataque",
                              result,
                              sourceEventId: eventId,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name → Ataque → $result"),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                        },
                      ),

                      ListTile(
                        leading: Icon(Icons.back_hand),
                        title: const Text("Receção"),
                        onTap: () async {

                          Navigator.pop(context);

                          final result = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => const ActionResultSheet(
                              title: "Resultado da Receção",
                              options: [
                                "Bola A",
                                "Bola B",
                                "Bola C",
                                "Erro",
                              ],
                            ),
                          );

                          if (result != null) {

                            final eventId =
                            await context.read<MatchEventProvider>().addEvent(
                              MatchEvent(
                                matchId: matchId,
                                playerId: playerId,
                                action: "Receção",
                                result: result,
                                setNumber: currentSet,
                                rallyId: currentRallyId,
                              ),
                            );

                            await processResult(
                              "Receção",
                              result,
                              sourceEventId: eventId,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name → Receção → $result"),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                        },
                      ),

                      ListTile(
                        leading: Icon(Icons.shield),
                        title: const Text("Bloco"),
                        onTap: () async {

                          Navigator.pop(context);

                          final result = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => const ActionResultSheet(
                              title: "Resultado do Bloco",
                              options: [
                                "Ponto",
                                "Toque",
                                "Erro",
                              ],
                            ),
                          );

                          if (result != null) {

                            final eventId =
                            await context.read<MatchEventProvider>().addEvent(
                              MatchEvent(
                                matchId: matchId,
                                playerId: playerId,
                                action: "Bloco",
                                result: result,
                                setNumber: currentSet,
                                rallyId: currentRallyId,
                              ),
                            );

                            await processResult(
                              "Bloco",
                              result,
                              sourceEventId: eventId,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name → Bloco → $result"),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                        },
                      ),

                      ListTile(
                        leading: Icon(Icons.sports_kabaddi),
                        title: const Text("Defesa"),
                        onTap: () async {

                          Navigator.pop(context);

                          final result = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => const ActionResultSheet(
                              title: "Resultado da Defesa",
                              options: [
                                "Excelente",
                                "Positiva",
                                "Continuação",
                                "Erro",
                              ],
                            ),
                          );

                          if (result != null) {

                            final eventId =
                            await context.read<MatchEventProvider>().addEvent(
                              MatchEvent(
                                matchId: matchId,
                                playerId: playerId,
                                action: "Defesa",
                                result: result,
                                setNumber: currentSet,
                                rallyId: currentRallyId,
                              ),
                            );

                            await processResult(
                              "Defesa",
                              result,
                              sourceEventId: eventId,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("$name → Defesa → $result"),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.alt_route),
                        title: const Text('Distribuição'),
                        onTap: () async {
                          Navigator.pop(context);

                          final result =
                          await showDistributionSheet();

                          if (result == null) return;

                          final eventId = await context
                              .read<MatchEventProvider>()
                              .addEvent(
                            MatchEvent(
                              matchId: matchId,
                              playerId: playerId,
                              action: 'Distribuição',
                              result: result,
                              setNumber: currentSet,
                              rallyId: currentRallyId,
                            ),
                          );

                          await processResult(
                            'Distribuição',
                            result,
                            sourceEventId: eventId,
                          );

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$name → $result',
                              ),
                              duration:
                              const Duration(milliseconds: 900),
                            ),
                          );
                        },
                      ),

                      if ((position == 1 || position == 5 || position == 6) &&
                          liberos.isNotEmpty &&
                          activeLiberoId == null)
                        ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: const Text("Entrar Líbero"),
                          onTap: () async {
                            Navigator.pop(context);

                            final liberoId = await showModalBottomSheet<int>(
                              context: context,
                              builder: (_) {
                                return SafeArea(
                                  child: Wrap(
                                    children: [
                                      const ListTile(
                                        title: Text(
                                          "Quem entra?",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),

                                      const Divider(),

                                      ...liberos.map((libero) {
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.sports_volleyball,
                                          ),
                                          title: Text(
                                            "#${libero.number} ${libero.name}",
                                          ),
                                          onTap: () {
                                            Navigator.pop(
                                              context,
                                              libero.id,
                                            );
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              },
                            );

                            if (liberoId == null) return;

                            await enterLiberoAtPosition(
                              liberoId: liberoId,
                              position: position,
                            );
                          },
                        ),

                      // =====================================================
// CONTROLO DO LÍBERO QUE ESTÁ EM CAMPO
// =====================================================

                      if (activeLiberoId == playerId) ...[
                        const Divider(),

                        ListTile(
                          leading: const Icon(Icons.undo),
                          title: const Text("Retomar Jogadora"),
                          onTap: () async {
                            Navigator.pop(context);

                            await exitActiveLibero();
                          },
                        ),

                        if (liberos.any(
                              (libero) => libero.id != activeLiberoId,
                        ))
                          ListTile(
                            leading: const Icon(Icons.swap_horiz),
                            title: const Text("Trocar Líbero"),
                            onTap: () async {
                              Navigator.pop(context);

                              final newLiberoId =
                              await showModalBottomSheet<int>(
                                context: context,
                                builder: (_) {
                                  final availableLiberos = liberos
                                      .where(
                                        (libero) =>
                                    libero.id != activeLiberoId,
                                  )
                                      .toList();

                                  return SafeArea(
                                    child: Wrap(
                                      children: [
                                        const ListTile(
                                          title: Text(
                                            "Escolher novo líbero",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),

                                        const Divider(),

                                        ...availableLiberos.map(
                                              (libero) {
                                            return ListTile(
                                              leading: const Icon(
                                                Icons.sports_volleyball,
                                              ),
                                              title: Text(
                                                "#${libero.number} ${libero.name}",
                                              ),
                                              onTap: () {
                                                Navigator.pop(
                                                  context,
                                                  libero.id,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );

                              if (newLiberoId == null) return;

                              await switchActiveLibero(
                                newLiberoId,
                              );
                            },
                          ),
                      ],

                      if (activeLiberoId != playerId)
                        ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: Text(
                            "Substituição ($substitutionsUsed/6)",
                          ),
                          onTap: () async {
                            Navigator.pop(context);

                            if (substitutionsUsed >= 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Já foram utilizadas as 6 substituições deste set.",
                                  ),
                                ),
                              );
                              return;
                            }

                            int? starterId;

                            for (final pair in substitutionPairs.entries) {
                              if (pair.value == playerId) {
                                starterId = pair.key;
                                break;
                              }
                            }

                            List<Player> availablePlayers;

                            if (starterId != null) {
                              availablePlayers = squadPlayers
                                  .where(
                                    (player) => player.id == starterId,
                              )
                                  .toList();
                            }

                            else if (completedSubstitutionPairs.contains(
                              playerId,
                            )) {
                              availablePlayers = [];
                            }

                            else {
                              final playersInCourt = lineup
                                  .map((player) => player.id)
                                  .toSet();

                              final liberoIds = liberos
                                  .map((player) => player.id)
                                  .toSet();

                              availablePlayers = squadPlayers.where(
                                    (player) {
                                  final id = player.id;

                                  if (id == null) return false;

                                  if (playersInCourt.contains(id)) {
                                    return false;
                                  }

                                  if (liberoIds.contains(id)) {
                                    return false;
                                  }

                                  final alreadyUsed =
                                  substitutionPairs.entries.any(
                                        (pair) =>
                                    pair.key == id ||
                                        pair.value == id,
                                  );

                                  if (alreadyUsed) {
                                    return false;
                                  }

                                  return true;
                                },
                              ).toList();
                            }

                            if (availablePlayers.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Não existem jogadoras disponíveis para esta substituição.",
                                  ),
                                ),
                              );
                              return;
                            }

                            final incomingPlayerId =
                            await showModalBottomSheet<int>(
                              context: context,
                              builder: (_) {
                                return SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          "Substituir #$number $name",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),

                                      const Divider(),

                                      ...availablePlayers.map(
                                            (player) {
                                          return ListTile(
                                            leading: CircleAvatar(
                                              child: Text(
                                                player.number.toString(),
                                              ),
                                            ),
                                            title: Text(player.name),
                                            onTap: () {
                                              Navigator.pop(
                                                context,
                                                player.id,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );

                            if (incomingPlayerId == null) return;

                            await substitutePlayer(
                              outgoingPlayerId: playerId,
                              incomingPlayerId: incomingPlayerId,
                            );
                          },
                        ),

                    ],
                  ),
                );

              },
            );

          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              CircleAvatar(
                radius: 22,
                child: Text(
                  number,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                name,
                textAlign: TextAlign.center,
              ),

            ],
          ),
        );
      },
    );
  }

  Widget courtPlayer(Player player) {

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            CircleAvatar(
              radius: 22,
              child: Text(
                player.number.toString(),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              player.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

          ],
        ),
      ),
    );

  }
}