import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/match_provider.dart';
import 'providers/player_provider.dart';
import 'screens/home/home_screen.dart';
import 'providers/match_player_provider.dart';
import 'providers/match_lineup_provider.dart';
import 'providers/match_event_provider.dart';
import 'providers/match_libero_provider.dart';

import 'theme/app_theme.dart';


final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlayerProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => MatchProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => MatchPlayerProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => MatchLineupProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => MatchEventProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => MatchLiberoProvider(),
        ),
      ],

      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GCS',
        theme: AppTheme.theme,
        navigatorObservers: [
          routeObserver,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}