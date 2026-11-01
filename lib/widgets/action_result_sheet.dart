import 'package:flutter/material.dart';

class ActionResultSheet extends StatelessWidget {
  final String title;
  final List<String> options;

  const ActionResultSheet({
    super.key,
    required this.title,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Divider(height: 1),

          ...options.map(
                (option) => ListTile(
              title: Text(option),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context, option);
              },
            ),
          ),

          const SizedBox(height: 10),

        ],
      ),
    );
  }
}