import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../providers/player_provider.dart';
import '../../providers/match_libero_provider.dart';
import 'match_rotation_screen.dart';
import '../../providers/match_provider.dart';

class MatchLineupScreen extends StatefulWidget {
  final int matchId;

  const MatchLineupScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<MatchLineupScreen> createState() =>
      _MatchLineupScreenState();
}

class _MatchLineupScreenState extends State<MatchLineupScreen> {
  final List<int> liberoIds = [];

  List<Player> playersByPosition(
      List<Player> players,
      String position,
      ) {
    return players.where((player) {
      return player.primaryPosition == position ||
          player.secondaryPosition == position;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final players =
        context.watch<PlayerProvider>().activePlayers;

    final liberos = playersByPosition(players, "Líbero");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Líberos"),
      ),

      body: ListView(
        children: [

          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Seleciona as líberos deste jogo.\n"
                  "Podes escolher 0, 1 ou 2.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  const Text(
                    "🥎 Líberos (máx. 2)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...liberos.map((player) {

                    final checked =
                    liberoIds.contains(player.id);

                    return CheckboxListTile(
                      controlAffinity:
                      ListTileControlAffinity.trailing,

                      value: checked,

                      title: Text(
                        "#${player.number}  ${player.name}",
                      ),

                      onChanged: (value) {

                        setState(() {

                          if (value == true) {

                            if (liberoIds.length < 2 &&
                                !liberoIds.contains(player.id)) {
                              liberoIds.add(player.id!);
                            }

                          } else {

                            liberoIds.remove(player.id);

                          }

                        });

                      },
                    );

                  }),

                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                final liberoProvider = context.read<MatchLiberoProvider>();
                final matchProvider = context.read<MatchProvider>();
                final navigator = Navigator.of(context);

                await liberoProvider.saveLiberos(
                  widget.matchId,
                  liberoIds,
                );

                if (!context.mounted) return;

                final match = matchProvider.matches.firstWhere(
                      (m) => m.id == widget.matchId,
                );

                final firstServer = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text("Quem inicia o serviço?"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.sports_volleyball),
                            title: const Text("GCS"),
                            onTap: () => Navigator.pop(dialogContext, true),
                          ),
                          ListTile(
                            leading: const Icon(Icons.sports_volleyball),
                            title: Text(match.opponent),
                            onTap: () => Navigator.pop(dialogContext, false),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (!mounted || firstServer == null) return;

                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => MatchRotationScreen(
                      matchId: widget.matchId,
                      setterId: 0,
                      oppositeId: 0,
                      middleIds: const [],
                      outsideIds: const [],
                      setNumber: 1,
                      gcsServing: firstServer,
                      firstServer: firstServer,
                      gcsSets: 0,
                      opponentSets: 0,
                    ),
                  ),
                );
              },

              child: const Text(
                "Continuar para posições iniciais",
              ),
            ),
          ),

        ],
      ),
    );
  }
}