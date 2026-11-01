import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../providers/player_provider.dart';
import 'player_form_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String search = "";

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<PlayerProvider>().loadPlayers();
    });
  }

  Future<void> _showPlayerMenu(Player player) async {
    final provider = context.read<PlayerProvider>();

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Editar"),
                onTap: () => Navigator.pop(context, "edit"),
              ),
              ListTile(
                leading: Icon(
                  player.status == "Ativa"
                      ? Icons.person_off
                      : Icons.person,
                ),
                title: Text(
                  player.status == "Ativa"
                      ? "Inativar"
                      : "Ativar",
                ),
                onTap: () => Navigator.pop(context, "status"),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                title: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, "delete"),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    switch (action) {
      case "edit":
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerFormScreen(player: player),
          ),
        );

        if (mounted) {
          provider.loadPlayers();
        }
        break;

      case "status":
        final updated = player.copyWith(
          status: player.status == "Ativa"
              ? "Inativa"
              : "Ativa",
        );

        await provider.updatePlayer(updated);
        break;

      case "delete":
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Eliminar jogadora"),
            content: Text(
              "Pretende eliminar ${player.name}?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Eliminar"),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await provider.deletePlayer(player.id!);
        }

        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayerProvider>();

    final filteredPlayers = provider.players.where((player) {
      return player.name.toLowerCase().contains(search) ||
          player.number.toString().contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Plantel"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Pesquisar por nome ou número...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  search = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: filteredPlayers.isEmpty
                ? const Center(
              child: Text(
                "Nenhuma jogadora encontrada.",
                style: TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: filteredPlayers.length,
              itemBuilder: (context, index) {
                final player = filteredPlayers[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showPlayerMenu(player),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(player.number.toString()),
                      ),
                      title: Text(
                        player.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        player.secondaryPosition == null ||
                            player.secondaryPosition!.isEmpty
                            ? player.primaryPosition
                            : "${player.primaryPosition} • ${player.secondaryPosition}",
                      ),
                      trailing: Chip(
                        label: Text(player.status),
                        backgroundColor: player.status == "Ativa"
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlayerFormScreen(),
            ),
          );

          if (mounted) {
            context.read<PlayerProvider>().loadPlayers();
          }
        },
      ),
    );
  }
}