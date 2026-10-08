import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';

class ReferenceChooser extends StatefulWidget {
  const ReferenceChooser({
    super.key,
    required this.catalog,
    required this.kind,
    required this.selected,
    required this.onExample,
  });
  final SharedCatalog catalog;
  final String kind;
  final CatalogEntry? selected;
  final void Function(CatalogEntry) onExample;

  @override
  State<ReferenceChooser> createState() => _ReferenceChooserState();
}

class _ReferenceChooserState extends State<ReferenceChooser> {
  String? package;

  @override
  Widget build(BuildContext context) {
    final packages = widget.catalog.packages(widget.kind);
    final entries = widget.catalog.entries
        .where((entry) => entry.kind == widget.kind)
        .toList();
    final title = widget.kind == 'pose'
        ? 'Posture packages'
        : widget.kind == 'landscape'
        ? 'Landscape packages'
        : 'Food recipes';
    final showGrid = package != null || widget.kind == 'food';
    return Column(
      children: [
        ListTile(
          leading: package == null
              ? null
              : IconButton(
                  tooltip: 'Back to packages',
                  onPressed: () => setState(() => package = null),
                  icon: const Icon(Icons.arrow_back),
                ),
          title: Text(package == null ? title : packages[package]!),
          trailing: IconButton(
            tooltip: 'Close packages',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.eco, color: Colors.teal),
          title: const Text('Natural'),
          subtitle: Text(
            widget.kind == 'landscape'
                ? 'No composition recipe; horizon guidance stays on'
                : widget.kind == 'food'
                ? 'No food recipe; framing guidance stays on'
                : 'No posture selected; live framing guidance stays on',
          ),
          trailing: widget.selected == null
              ? const Icon(Icons.check_circle, color: Colors.teal)
              : null,
          onTap: () => Navigator.pop(context, 'natural'),
        ),
        if (package == null && widget.kind != 'food')
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.kind == 'pose'
                  ? 'Choose a package'
                  : 'Choose a landscape package',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        if (package != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.catalog.packageDescription(widget.kind, package!),
            ),
          ),

        Expanded(
          child: showGrid
              ? LayoutBuilder(
                  builder: (context, bounds) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final width = bounds.maxWidth / (scale > 1.5 ? 1 : 2);
                    return SingleChildScrollView(
                      child: Wrap(
                        children: [
                          for (final entry in entries.where(
                            (entry) =>
                                package == null || entry.package == package,
                          ))
                            SizedBox(
                              width: width,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: Key('reference_${entry.id}'),
                                  onTap: () => Navigator.pop(context, entry),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Image.asset(
                                        entry.asset,
                                        cacheWidth: 512,
                                        height: 180,
                                        fit: BoxFit.cover,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(entry.title),
                                                ),
                                                IconButton(
                                                  key: Key(
                                                    'example_${entry.id}',
                                                  ),
                                                  tooltip:
                                                      'Photo example of ${entry.title}',
                                                  onPressed: () =>
                                                      widget.onExample(entry),
                                                  icon: const Icon(
                                                    Icons.info_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              widget.catalog.angleTitle(entry),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                            Text(
                                              'Best light: ${widget.catalog.lightTitle(entry)}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                            if (widget.selected?.id == entry.id)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.tealAccent,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                )
              : ListView(
                  children: [
                    for (final group in packages.entries)
                      Card(
                        child: ListTile(
                          key: Key('package_${group.key}'),
                          leading: SizedBox(
                            width: 126,
                            child: Row(
                              children: [
                                for (final entry
                                    in entries
                                        .where(
                                          (entry) => entry.package == group.key,
                                        )
                                        .take(3))
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      child: Image.asset(
                                        entry.asset,
                                        cacheWidth: 128,
                                        height: 86,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          title: Text(group.value),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entries.where((entry) => entry.package == group.key).length} ${widget.kind == 'pose' ? 'poses' : 'compositions'}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                widget.catalog.packageDescription(
                                  widget.kind,
                                  group.key,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            widget.selected?.package == group.key
                                ? Icons.check_circle
                                : Icons.chevron_right,
                          ),
                          onTap: () => setState(() => package = group.key),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
