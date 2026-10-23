import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutSettingsContent extends StatelessWidget {
  const AboutSettingsContent({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ListTile(title: Text('App'), subtitle: Text('Dali Camera')),
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (_, result) => ListTile(
          title: const Text('Version'),
          subtitle: Text(
            result.hasData
                ? '${result.data!.version} (${result.data!.buildNumber})'
                : result.hasError
                ? 'Unavailable'
                : 'Checking…',
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Live photography guidance, camera controls, capture effects, and photo enhancement.',
        ),
      ),
    ],
  );
}

class HelpSettingsContent extends StatelessWidget {
  const HelpSettingsContent({
    super.key,
    required this.onTutorial,
    required this.onHelp,
  });

  final VoidCallback onTutorial;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text('Quick camera tutorial'),
        onTap: onTutorial,
      ),
      ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Camera help'),
        onTap: onHelp,
      ),
    ],
  );
}
