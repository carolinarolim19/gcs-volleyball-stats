import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/menu_button.dart';
import '../players/players_screen.dart';
import '../matches/matches_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [

                  const SizedBox(height: 10),

                  Hero(
                    tag: "logo",
                    child: Image.asset(
                      "assets/images/gcs_logo.png",
                      height: 170,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "GCS",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "Ginásio Clube de Sines",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Estatística de Voleibol",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 40),

                  MenuButton(
                    title: "Jogo",
                    icon: Icons.sports_volleyball,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MatchesScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 15),

                  MenuButton(
                    title: "Plantel",
                    icon: Icons.people,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlayersScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 15),

                  MenuButton(
                    title: "Equipas",
                    icon: Icons.groups,
                    onTap: () {},
                  ),

                  const SizedBox(height: 15),

                  MenuButton(
                    title: "Definições",
                    icon: Icons.settings,
                    onTap: () {},
                  ),

                  const Spacer(),

                  Text(
                    "Versão 2.1",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}