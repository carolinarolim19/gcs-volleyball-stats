import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../providers/match_lineup_provider.dart';
import 'game_screen.dart';
import '../../providers/match_player_provider.dart';
import '../../providers/match_libero_provider.dart';

class MatchRotationScreen extends StatefulWidget {
  final int matchId;

  final int setterId;
  final int oppositeId;
  final List<int> middleIds;
  final List<int> outsideIds;
  final int setNumber;
  final bool gcsServing;
  final int gcsSets;
  final int opponentSets;
  final bool firstServer;

  const MatchRotationScreen({
    super.key,
    required this.matchId,
    required this.setterId,
    required this.oppositeId,
    required this.middleIds,
    required this.outsideIds,
    required this.setNumber,
    required this.gcsServing,
    required this.gcsSets,
    required this.opponentSets,
    required this.firstServer,
  });

  @override
  State<MatchRotationScreen> createState() =>
      _MatchRotationScreenState();
}

class _MatchRotationScreenState extends State<MatchRotationScreen> {

  int? p1;
  int? p2;
  int? p3;
  int? p4;
  int? p5;
  int? p6;

  List<int> selectedPlayers = [];

  @override
  void initState() {
    super.initState();

    _loadSquad();
  }

  Future<void> _loadSquad() async {
    final matchPlayerProvider = context.read<MatchPlayerProvider>();
    final liberoProvider = context.read<MatchLiberoProvider>();

    final squad = await matchPlayerProvider.getSquad(widget.matchId);

    await liberoProvider.loadLiberos(widget.matchId);

    final liberoIds = liberoProvider.currentLiberos
        .map((libero) => libero.playerId)
        .toSet();

    final fieldPlayers = squad
        .where((playerId) => !liberoIds.contains(playerId))
        .toList();

    if (!mounted) return;

    setState(() {
      selectedPlayers = fieldPlayers;
    });
  }

  bool alreadySelected(int playerId, int? currentPosition) {
    return [
      p1,
      p2,
      p3,
      p4,
      p5,
      p6,
    ].any((id) => id == playerId && id != currentPosition);
  }

  String playerName(int id) {


    final player = context.read<PlayerProvider>().players.firstWhere(
          (p) => p.id == id,
    );

    return "#${player.number} ${player.name}";
  }

  Widget buildPosition({
    required String title,
    required int? selectedId,
    required ValueChanged<int?> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButton<int>(
              isExpanded: true,
              value: selectedId,
              hint: const Text("Escolher"),

              items: selectedPlayers.map((id) {

                final disabled = alreadySelected(id, selectedId);

                return DropdownMenuItem<int>(
                  value: id,
                  enabled: !disabled,
                  child: Text(
                    playerName(id),
                    style: TextStyle(
                      color: disabled ? Colors.grey : null,
                    ),
                  ),
                );

              }).toList(),

              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Posições Iniciais"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const Text(
              "REDE",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                Expanded(
                  child: buildPosition(
                    title: "P4",
                    selectedId: p4,
                    onChanged: (value) {
                      setState(() {
                        p4 = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: buildPosition(
                    title: "P3",
                    selectedId: p3,
                    onChanged: (value) {
                      setState(() {
                        p3 = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: buildPosition(
                    title: "P2",
                    selectedId: p2,
                    onChanged: (value) {
                      setState(() {
                        p2 = value;
                      });
                    },
                  ),
                ),

              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                Expanded(
                  child: buildPosition(
                    title: "P5",
                    selectedId: p5,
                    onChanged: (value) {
                      setState(() {
                        p5 = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: buildPosition(
                    title: "P6",
                    selectedId: p6,
                    onChanged: (value) {
                      setState(() {
                        p6 = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: buildPosition(
                    title: "P1",
                    selectedId: p1,
                    onChanged: (value) {
                      setState(() {
                        p1 = value;
                      });
                    },
                  ),
                ),

              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Começar Jogo"),
                onPressed: () async {

                  if (p1 == null ||
                      p2 == null ||
                      p3 == null ||
                      p4 == null ||
                      p5 == null ||
                      p6 == null) {

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Define as seis posições antes de continuar.",
                        ),
                      ),
                    );

                    return;
                  }


                  final navigator = Navigator.of(context);

                  final lineup = <int, int>{
                    1: p1!,
                    2: p2!,
                    3: p3!,
                    4: p4!,
                    5: p5!,
                    6: p6!,
                  };

                  await context.read<MatchLineupProvider>().saveLineup(
                    widget.matchId,
                    widget.setNumber,
                    lineup,
                  );

                  if (!mounted) return;

                  navigator.pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        matchId: widget.matchId,
                        setNumber: widget.setNumber,
                        gcsServing: widget.gcsServing,
                        firstServer: widget.firstServer,
                        gcsSets: widget.gcsSets,
                        opponentSets: widget.opponentSets,
                      ),
                    ),
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}
