import 'package:audioplayers/audioplayers.dart';

import '../data/money_transaction.dart';
import 'sound_library.dart';

/// Satu player dipakai bergantian supaya ketukan cepat tidak menumpuk
/// dua lagu sekaligus.
class SoundFx {
  SoundFx._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(SoundOption option) async {
    if (option.isSilent) return;
    try {
      await _player.stop();
      final file = option.file;
      if (file != null) {
        await _player.play(DeviceFileSource(file));
        return;
      }
      final asset = option.asset;
      if (asset == null) return;
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Suara hanyalah hiasan; kegagalan audio tidak boleh menggagalkan simpan.
    }
  }

  static Future<void> dispose() => _player.dispose();
}

/// Dampak satu transaksi terhadap total saldo.
/// Pindah dompet tidak mengubah total, jadi nol.
int balanceDeltaOf(MoneyTransaction transaction) {
  if (transaction.isTransfer) return 0;
  if (transaction.isIncome) return transaction.amount;
  if (transaction.isExpense) return -transaction.amount;
  return transaction.amount;
}
