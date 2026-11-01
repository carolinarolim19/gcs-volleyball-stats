import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../providers/match_provider.dart';
import 'match_form_screen.dart';
import 'game_screen.dart';
import '../../database/match_game_state_repository.dart';
import '../../database/match_set_state_repository.dart';
import '../../database/match_substitution_state_repository.dart';
import '../../database/match_lineup_repository.dart';
import '../../database/match_player_repository.dart';
import '../../database/match_event_repository.dart';
import '../../database/match_libero_repository.dart';
import 'match_rotation_screen.dart';
import '../../database/match_point_undo_state_repository.dart';
import '../../database/match_set_participation_repository.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/player_provider.dart';
import '../../providers/match_player_provider.dart';
import '../../providers/match_event_provider.dart';
import '../../services/match_excel_export_service.dart';
import '../../models/player.dart';
import '../../models/match_event.dart';
import 'package:flutter/foundation.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with RouteAware {

  @override
  void initState() {
    super.initState();

    final matchProvider = context.read<MatchProvider>();

    Future.microtask(() {
      matchProvider.loadMatches();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of<void>(context);

    if (route != null) {
      routeObserver.subscribe(
        this,
        route,
      );
    }
  }

  @override
  void didPopNext() async {
    super.didPopNext();

    if (!mounted) return;

    await context.read<MatchProvider>().loadMatches();

    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MatchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jogos"),
      ),
      body: provider.matches.isEmpty
          ? const Center(
        child: Text(
          "Nenhum jogo registado.",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.matches.length,
        itemBuilder: (context, index) {
          final match = provider.matches[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.sports_volleyball),
              ),
              title: Text(
                "GCS vs ${match.opponent}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (match.competition.isNotEmpty)
                    Text(match.competition),

                  const SizedBox(height: 4),

                  Text(
                    DateFormat(
                      "dd/MM/yyyy",
                    ).format(match.dateTime),
                  ),

                  Text(
                    match.home ? "🏠 Casa" : "🚍 Fora",
                  ),

                  Text(
                    "🥇 Melhor de ${match.sets}",
                  ),

                  Text(
                    match.official
                        ? "🏆 Oficial"
                        : "🤝 Amigável",
                  ),
                  if (match.finished)
                    Text(
                      "🏁 Resultado: GCS ${match.gcsSets}-${match.opponentSets} ${match.opponent}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),

              trailing: FutureBuilder<Map<String, dynamic>?>(
                future: MatchGameStateRepository().getState(
                  match.id!,
                ),
                builder: (context, snapshot) {
                  final hasGameInProgress =
                      snapshot.data != null;

                  return PopupMenuButton<String>(
                    onSelected: (value) async {

                      if (value == "continue") {
                        final gameStateRepository =
                        MatchGameStateRepository();

                        final state =
                        await gameStateRepository.getState(
                          match.id!,
                        );

                        final currentSet =
                            state?['currentSet'] as int? ?? 1;

                        final gcsSets =
                            state?['gcsSets'] as int? ?? 0;

                        final opponentSets =
                            state?['opponentSets'] as int? ?? 0;

                        final gcsServing = state != null
                            ? state['gcsServing'] == 1
                            : match.firstServer;

                        final savedLineup =
                        await MatchLineupRepository().getByMatchAndSet(
                          match.id!,
                          currentSet,
                        );

                        if (!context.mounted) return;

                        if (savedLineup.isEmpty) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MatchRotationScreen(
                                matchId: match.id!,
                                setterId: 0,
                                oppositeId: 0,
                                middleIds: const [],
                                outsideIds: const [],
                                setNumber: currentSet,
                                gcsServing: gcsServing,
                                firstServer: match.firstServer,
                                gcsSets: gcsSets,
                                opponentSets: opponentSets,
                              ),
                            ),
                          );
                        } else {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GameScreen(
                                matchId: match.id!,
                                setNumber: currentSet,
                                gcsServing: gcsServing,
                                firstServer: match.firstServer,
                                gcsSets: gcsSets,
                                opponentSets: opponentSets,
                              ),
                            ),
                          );
                        }

                        if (!context.mounted) return;

                        setState(() {});
                      }

                      if (value == "export") {
                        final playerProvider =
                        context.read<PlayerProvider>();

                        final matchPlayerProvider =
                        context.read<MatchPlayerProvider>();

                        final eventProvider =
                        context.read<MatchEventProvider>();

                        final excelService =
                        MatchExcelExportService();

                        await playerProvider.loadPlayers();

                        final finishedMatches = provider.matches
                            .where((item) => item.finished)
                            .toList()
                          ..sort(
                                (a, b) => a.dateTime.compareTo(
                              b.dateTime,
                            ),
                          );

                        final playersByMatch =
                        <int, List<Player>>{};

                        final eventsByMatch =
                        <int, List<MatchEvent>>{};

                        for (final finishedMatch in finishedMatches) {
                          final finishedMatchId =
                              finishedMatch.id;

                          if (finishedMatchId == null) {
                            continue;
                          }

                          final squadIds =
                          await matchPlayerProvider.getSquad(
                            finishedMatchId,
                          );

                          final players = squadIds.map((playerId) {
                            return playerProvider.players.firstWhere(
                                  (player) => player.id == playerId,
                            );
                          }).toList();

                          await eventProvider.loadEvents(
                            finishedMatchId,
                          );

                          final events = eventProvider.events
                              .where(
                                (event) =>
                            event.matchId == finishedMatchId,
                          )
                              .toList();

                          playersByMatch[finishedMatchId] =
                              players;

                          eventsByMatch[finishedMatchId] =
                              events;
                        }

                        final excelBytes = await excelService.exportAllMatches(
                          matches: finishedMatches,
                          playersByMatch: playersByMatch,
                          eventsByMatch: eventsByMatch,
                        );

                        if (!context.mounted) return;

                        if (kIsWeb) {
                          excelService.downloadExcelWeb(excelBytes);
                        } else {
                          final excelFile = await excelService.getExcelFile();

                          if (!await excelFile.exists()) return;

                          await SharePlus.instance.share(
                            ShareParams(
                              files: [
                                XFile(excelFile.path),
                              ],
                              subject: 'GCS - Estatísticas 2026/2027',
                            ),
                          );
                        }
                      }

                      if (!context.mounted) return;

                      final navigator = Navigator.of(context);
                      final matchProvider = context.read<MatchProvider>();

                      if (value == "edit") {
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (_) => MatchFormScreen(
                              match: match,
                            ),
                          ),
                        );

                        if (!mounted) return;

                        matchProvider.loadMatches();
                      }

                      if (value == "delete") {
                        if (!context.mounted) return;
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text("Eliminar jogo"),
                            content: Text(
                              "Pretende eliminar o jogo contra ${match.opponent}?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text("Cancelar"),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text("Eliminar"),
                              ),
                            ],
                          ),
                        );

                        if (!context.mounted) return;

                        if (confirmar == true) {
                          final matchId = match.id!;
                          final matchProvider = context.read<MatchProvider>();

                          await MatchGameStateRepository().clearState(matchId);
                          await MatchSetStateRepository().clearMatch(matchId);
                          await MatchSubstitutionStateRepository().clearMatch(matchId);
                          await MatchPointUndoStateRepository().clearMatch(matchId);
                          await MatchSetParticipationRepository().clearMatch(matchId);
                          await MatchLineupRepository().deleteByMatch(matchId);
                          await MatchPlayerRepository().deleteByMatch(matchId);
                          await MatchEventRepository().deleteAllFromMatch(matchId);
                          await MatchLiberoRepository().deleteByMatch(matchId);

                          await matchProvider.deleteMatch(matchId);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Jogo eliminado.",
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },

                    itemBuilder: (_) => [
                      if (hasGameInProgress)
                        const PopupMenuItem(
                          value: "continue",
                          child: Text("Continuar Jogo"),
                        ),

                      if (match.finished)
                        const PopupMenuItem(
                          value: "export",
                          child: Text("Extrair Jogo"),
                        ),

                      const PopupMenuItem(
                        value: "edit",
                        child: Text("Editar"),
                      ),

                      const PopupMenuItem(
                        value: "delete",
                        child: Text("Eliminar"),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Jogo"),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MatchFormScreen(),
            ),
          );

          if (context.mounted) {
            context.read<MatchProvider>().loadMatches();
          }
        },
      ),
    );
  }
}