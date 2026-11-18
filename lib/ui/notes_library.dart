import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/day_note.dart';
import '../state/settings_store.dart';
import '../util/format.dart';
import 'motion.dart';
import 'tab_layout.dart';
import 'theme.dart';

class NotesToolbar extends StatelessWidget {
  const NotesToolbar({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final colors = EsokColors.of(context);
    final compact = MediaQuery.sizeOf(context).height < 480;
    final detail = MediaQuery.textScalerOf(context).scale(13) * 1.4;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 48 : 62 + detail),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EsokTabLayout.gutter),
        child: Align(
          heightFactor: 1,
          child: _controls(context, settings, colors),
        ),
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    SettingsStore settings,
    EsokPalette colors,
  ) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text('$count catatan', style: Theme.of(context).textTheme.bodyMedium),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            IconButton(
              isSelected: settings.notesGrid,
              tooltip: 'Tampilan kotak',
              onPressed: () => settings.setNotesGrid(true),
              icon: const Icon(Icons.grid_view_rounded, size: 19),
              style: _layoutStyle(colors, settings.notesGrid),
            ),
            IconButton(
              isSelected: !settings.notesGrid,
              tooltip: 'Tampilan daftar',
              onPressed: () => settings.setNotesGrid(false),
              icon: const Icon(Icons.view_agenda_outlined, size: 19),
              style: _layoutStyle(colors, !settings.notesGrid),
            ),
            PopupMenuButton<NoteSort>(
              tooltip: 'Urutkan catatan',
              icon: const Icon(Icons.sort_rounded, size: 21),
              onSelected: settings.setNoteSort,
              itemBuilder: (_) => [
                for (final sort in NoteSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: settings.noteSort == sort,
                    child: Text(sort.label),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  ButtonStyle _layoutStyle(EsokPalette colors, bool selected) =>
      IconButton.styleFrom(
        backgroundColor: selected ? colors.control : Colors.transparent,
        foregroundColor: selected ? colors.ink : colors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

class NotesLibrary extends StatelessWidget {
  const NotesLibrary({
    super.key,
    required this.notes,
    required this.onOpen,
    required this.onCreate,
  });

  final List<DayNote> notes;
  final ValueChanged<DayNote> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final sorted = [...notes]
      ..sort((a, b) {
        final order = switch (settings.noteSort) {
          NoteSort.edited => b.updatedAt.compareTo(a.updatedAt),
          NoteSort.newest => b.createdAt.compareTo(a.createdAt),
          NoteSort.oldest => a.createdAt.compareTo(b.createdAt),
          NoteSort.title => a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          ),
        };
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final padding = EdgeInsets.fromLTRB(
      EsokTabLayout.gutter,
      12,
      EsokTabLayout.gutter,
      EsokTabLayout.scrollBottomOf(context),
    );
    if (sorted.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          Text(
            'Belum ada catatan.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onCreate,
              child: const Text('Tulis catatan'),
            ),
          ),
        ],
      );
    }
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final grid = settings.notesGrid;
    final tiles = LayoutBuilder(
      builder: (context, constraints) {
        if (!grid) {
          return ListView.separated(
            padding: padding,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, index) => _NoteTile(
              note: sorted[index],
              grid: false,
              onTap: () => onOpen(sorted[index]),
            ),
          );
        }
        final columns =
            ((constraints.maxWidth - padding.horizontal) / (150 * scale))
                .floor()
                .clamp(1, 4);
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 31 + 93 * scale,
          ),
          itemCount: sorted.length,
          itemBuilder: (_, index) => _NoteTile(
            note: sorted[index],
            grid: true,
            onTap: () => onOpen(sorted[index]),
          ),
        );
      },
    );
    return AnimatedSwitcher(
      duration: EsokMotion.reduced(context)
          ? Duration.zero
          : EsokMotion.feedback,
      switchInCurve: EsokMotion.settle,
      child: KeyedSubtree(key: ValueKey(grid), child: tiles),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.grid,
    required this.onTap,
  });

  final DayNote note;
  final bool grid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final theme = Theme.of(context).textTheme;
    final title = note.displayTitle;
    final updated = DateTime.fromMillisecondsSinceEpoch(note.updatedAt);
    final preview = Text(
      note.body,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.bodyMedium,
    );
    final radius = BorderRadius.circular(12);
    return Material(
      color: grid ? colors.surface : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: grid ? 12 : 2,
            vertical: 10,
          ),
          child: Column(
            mainAxisSize: grid ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: grid ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (grid)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: preview,
                  ),
                )
              else if (note.body.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: preview),
              const SizedBox(height: 4),
              Text(dateTitle(updated), style: theme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
