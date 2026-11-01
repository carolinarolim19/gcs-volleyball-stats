import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../providers/player_provider.dart';

class PlayerFormScreen extends StatefulWidget {
  final Player? player;

  const PlayerFormScreen({
    super.key,
    this.player,
  });

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.player != null) {
      _numberController.text = widget.player!.number.toString();
      _nameController.text = widget.player!.name;

      primaryPosition = widget.player!.primaryPosition;
      secondaryPosition = widget.player!.secondaryPosition;
      status = widget.player!.status;
    }
  }

  final List<String> positions = [
    'Distribuidor',
    'Oposto',
    'Central',
    'Zona 4',
    'Líbero',
    'Universal',
  ];

  final List<String> statusList = [
    'Ativa',
    'Lesionada',
    'Ausente',
  ];

  String primaryPosition = 'Distribuidor';
  String? secondaryPosition;
  String status = 'Ativa';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.player == null
              ? "Nova Jogadora"
              : "Editar Jogadora",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Número",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Introduz o número";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nome",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Introduz o nome";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: primaryPosition,
                decoration: const InputDecoration(
                  labelText: "Posição Principal",
                ),
                items: positions
                    .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    primaryPosition = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String?>(
                value: secondaryPosition,
                decoration: const InputDecoration(
                  labelText: "Posição Secundária",
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Nenhuma"),
                  ),
                  ...positions.map(
                        (e) => DropdownMenuItem<String?>(
                      value: e,
                      child: Text(e),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    secondaryPosition = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                  labelText: "Estado",
                ),
                items: statusList
                    .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    status = value!;
                  });
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  child: const Text(
                    "Guardar",
                    style: TextStyle(fontSize: 20),
                  ),
                  onPressed: () async {

                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    final provider = context.read<PlayerProvider>();

                    final exists = await provider.numberExists(
                      int.parse(_numberController.text),
                      ignoreId: widget.player?.id,
                    );

                    if (exists) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Já existe uma jogadora com esse número."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final player = Player(
                      id: widget.player?.id,
                      number: int.parse(_numberController.text),
                      name: _nameController.text,
                      primaryPosition: primaryPosition,
                      secondaryPosition: secondaryPosition,
                      status: status,
                    );

                    if (widget.player == null) {
                      await context.read<PlayerProvider>().addPlayer(player);
                    } else {
                      await context.read<PlayerProvider>().updatePlayer(player);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}