import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'update_controller.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});
  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> with WidgetsBindingObserver {
  final controller = UpdateController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.loadInstalled());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.onResume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pembaruan aplikasi')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final target = controller.release;
        final status = switch (phase) {
          UpdatePhase.idle => 'Periksa rilis baru dari GitHub Oh My Esok.',
          UpdatePhase.checking => 'Memeriksa pembaruan…',
          UpdatePhase.available => 'Pembaruan tersedia',
          UpdatePhase.upToDate => 'Versi kamu sudah terbaru.',
          UpdatePhase.noRelease =>
            'Belum ada rilis ${controller.allowPreview ? 'yang dapat diunduh' : 'stabil'}.',
          UpdatePhase.downloading =>
            'Mengunduh ${(controller.progress * 100).round()}%',
          UpdatePhase.verifying => 'Memeriksa integritas dan tanda tangan APK…',
          UpdatePhase.ready => 'Siap dipasang',
          UpdatePhase.permissionRequired =>
            'Izinkan aplikasi ini memasang pembaruan lewat setelan Android.',
          UpdatePhase.awaitingAndroid => 'Lanjutkan konfirmasi di Android.',
          UpdatePhase.failed => 'Belum berhasil memperbarui.',
        };
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Versi terpasang',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(controller.installedVersion),
            const SizedBox(height: 28),
            Text(status, style: Theme.of(context).textTheme.titleMedium),
            if (controller.message != null) ...[
              const SizedBox(height: 10),
              Text(controller.message!),
            ],
            if (target != null) ...[
              const SizedBox(height: 12),
              Text(
                '${target.versionName} · ${(target.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB${target.preview ? ' · Prarilis' : ''}',
              ),
            ],
            if (phase == UpdatePhase.downloading ||
                phase == UpdatePhase.verifying) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: phase == UpdatePhase.downloading
                    ? controller.progress
                    : null,
              ),
            ],
            const SizedBox(height: 20),
            if (phase == UpdatePhase.available ||
                (phase == UpdatePhase.failed && target != null))
              FilledButton(
                onPressed: controller.download,
                child: const Text('Unduh pembaruan'),
              ),
            if (phase == UpdatePhase.downloading)
              OutlinedButton(
                onPressed: controller.cancelDownload,
                child: const Text('Batal unduh'),
              ),
            if (phase == UpdatePhase.ready)
              FilledButton(
                onPressed: controller.install,
                child: const Text('Pasang pembaruan'),
              ),
            if (phase == UpdatePhase.permissionRequired)
              FilledButton(
                onPressed: controller.openSources,
                child: const Text('Buka setelan Android'),
              ),
            if (!controller.busy)
              OutlinedButton(
                onPressed: controller.check,
                child: const Text('Cek pembaruan'),
              ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sertakan prarilis'),
              subtitle: const Text(
                'Versi untuk mencoba fitur baru sebelum rilis stabil.',
              ),
              value: controller.allowPreview,
              onChanged: controller.busy
                  ? null
                  : (value) => setState(() {
                      controller.allowPreview = value;
                      controller.release = null;
                      controller.notes = '';
                      controller.message = null;
                      controller.phase = UpdatePhase.idle;
                    }),
            ),
            if (controller.notes.isNotEmpty) ...[
              const Divider(height: 36),
              Text(
                'Apa yang baru',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SelectableText(controller.notes),
            ],
            const SizedBox(height: 24),
            const Text(
              'Pemasangan selalu meminta konfirmasi Android. Catatan dan buku kas tetap ada setelah pembaruan.',
            ),
          ],
        );
      },
    ),
  );
}
