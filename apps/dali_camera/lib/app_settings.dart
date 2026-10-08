import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'camera_tutorial.dart';

Future<void> showAppSettings(
  BuildContext context, {
  required Future<void> Function() onHelp,
  required Future<void> Function() onImport,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .8,
      child: Column(
        children: [
          ListTile(
            title: const Text('App Settings'),
            trailing: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Section('About'),
                  const ListTile(
                    title: Text('App'),
                    subtitle: Text('Dali Camera'),
                  ),
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
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Quick camera tutorial'),
                    onTap: () => Navigator.pop(ctx, 'tutorial'),
                  ),
                  const _Section('Language'),
                  const ListTile(
                    leading: Icon(Icons.language),
                    title: Text('Language choice'),
                    subtitle: Text('System default'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('Additional languages coming soon'),
                  ),
                  const _Section('Display'),
                  const ListTile(
                    leading: Icon(Icons.contrast),
                    title: Text('Display option'),
                    subtitle: Text('System appearance'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text(
                      'Light and dark appearance choices coming soon',
                    ),
                  ),
                  const _Section('Purchase'),
                  const ListTile(
                    leading: Icon(Icons.workspace_premium),
                    title: Text('Dali Pro'),
                    subtitle: Text('Coming soon'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Dali Pro will remove the signature watermark from captured photos and unlock premium camera features.',
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restore purchases'),
                    subtitle: Text('Coming soon'),
                  ),
                  const _Section('More'),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help'),
                    onTap: () => Navigator.pop(ctx, 'help'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_photo_alternate_outlined),
                    title: const Text('Import photos'),
                    onTap: () => Navigator.pop(ctx, 'import'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'tutorial') {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const CameraTutorial(),
      ),
    );
  } else if (action == 'help') {
    await onHelp();
  } else if (action == 'import') {
    await onImport();
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}
