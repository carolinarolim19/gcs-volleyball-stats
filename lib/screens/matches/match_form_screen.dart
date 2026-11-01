import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../providers/match_provider.dart';
import 'match_squad_screen.dart';

class MatchFormScreen extends StatefulWidget {
  final Match? match;

  const MatchFormScreen({
    super.key,
    this.match,
  });

  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final opponentController = TextEditingController();
  final competitionController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  bool home = true;
  int sets = 5;
  bool official = true;
  bool gcsLeft = true;
  bool firstServer = true;

  @override
  void initState() {
    super.initState();

    if (widget.match != null) {
      opponentController.text = widget.match!.opponent;
      competitionController.text = widget.match!.competition;

      selectedDate = widget.match!.dateTime;
      home = widget.match!.home;
      sets = widget.match!.sets;
      official = widget.match!.official;
    }
  }

  @override
  void dispose() {
    opponentController.dispose();
    competitionController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jogo"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              TextFormField(
                controller: opponentController,
                decoration: const InputDecoration(
                  labelText: "Adversário",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Introduz o adversário";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: competitionController,
                decoration: const InputDecoration(
                  labelText: "Competição",
                ),
              ),

              const SizedBox(height: 16),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              const Text(
                "Tipo de jogo",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              RadioListTile<bool>(
                value: true,
                groupValue: official,
                title: const Text("Oficial"),
                onChanged: (value) {
                  setState(() {
                    official = value!;
                  });
                },
              ),

              RadioListTile<bool>(
                value: false,
                groupValue: official,
                title: const Text("Amigável"),
                onChanged: (value) {
                  setState(() {
                    official = value!;
                  });
                },
              ),

              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                ),
                trailing: const Icon(Icons.edit),
                onTap: pickDate,
              ),

              const Divider(),

              const Text(
                "Local",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              RadioListTile(
                value: true,
                groupValue: home,
                title: const Text("Casa"),
                onChanged: (value) {
                  setState(() {
                    home = value!;
                  });
                },
              ),

              RadioListTile(
                value: false,
                groupValue: home,
                title: const Text("Fora"),
                onChanged: (value) {
                  setState(() {
                    home = value!;
                  });
                },
              ),

              const Divider(),

              const Text(
                "Melhor de",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              RadioListTile(
                value: 3,
                groupValue: sets,
                title: const Text("3 Sets"),
                onChanged: (value) {
                  setState(() {
                    sets = value!;
                  });
                },
              ),

              RadioListTile(
                value: 5,
                groupValue: sets,
                title: const Text("5 Sets"),
                onChanged: (value) {
                  setState(() {
                    sets = value!;
                  });
                },
              ),

              const SizedBox(height: 30),

              FilledButton(
                onPressed: () async {

                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final match = Match(
                    id: widget.match?.id,
                    opponent: opponentController.text,
                    competition: competitionController.text,
                    dateTime: selectedDate,
                    home: home,
                    sets: sets,
                    official: official,
                    gcsLeft: gcsLeft,

                  );

                  if (widget.match == null) {

                    final id = await context.read<MatchProvider>().addMatch(match);

                    if (!context.mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchSquadScreen(
                          matchId: id,
                        ),
                      ),
                    );

                  } else {

                    await context.read<MatchProvider>().updateMatch(match);

                    if (!context.mounted) return;

                    Navigator.pop(context);

                  }
                },
                child: const Text("Guardar"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
