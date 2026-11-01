import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../providers/player_provider.dart';
import '../../providers/match_player_provider.dart';
import 'match_lineup_screen.dart';

class MatchSquadScreen extends StatefulWidget {
  final int matchId;

  const MatchSquadScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<MatchSquadScreen> createState() => _MatchSquadScreenState();
}

class _MatchSquadScreenState extends State<MatchSquadScreen> {

  final Set<int> selectedPlayers = {};

  @override
  void initState() {
    super.initState();

    final playerProvider = context.read<PlayerProvider>();

    Future.microtask(() async {
      await playerProvider.loadPlayers();

      if (!mounted) return;

      final players = playerProvider.activePlayers;

      setState(() {
        selectedPlayers.addAll(
          players.map((e) => e.id!),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {

    final players =
        context.watch<PlayerProvider>().activePlayers;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Convocatória"),
      ),

      body: Column(
        children: [

          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              "${selectedPlayers.length} convocadas",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {

                final Player player = players[index];

                final checked =
                selectedPlayers.contains(player.id);

                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.trailing,
                  value: checked,

                  title: Text(
                    "#${player.number}  ${player.name}",
                  ),

                  subtitle: Text(
                    player.secondaryPosition == null ||
                        player.secondaryPosition!.isEmpty
                        ? player.primaryPosition
                        : "${player.primaryPosition} • ${player.secondaryPosition}",
                  ),

                  onChanged: (value) {

                    setState(() {

                      if (value!) {
                        selectedPlayers.add(player.id!);
                      } else {
                        selectedPlayers.remove(player.id);
                      }

                    });

                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {

                if (selectedPlayers.length < 6) {

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "É necessário convocar pelo menos 6 atletas.",
                      ),
                    ),
                  );

                  return;
                }

                if (selectedPlayers.length > 14) {

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Máximo de 14 atletas.",
                      ),
                    ),
                  );

                  return;
                }

                await context.read<MatchPlayerProvider>().saveSquad(
                  widget.matchId,
                  selectedPlayers.toList(),
                );

                if (!context.mounted) return;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchLineupScreen(
                      matchId: widget.matchId,
                    ),
                  ),
                );

              },
              child: const Text("Continuar"),
            ),
          )

        ],
      ),
    );
  }
}