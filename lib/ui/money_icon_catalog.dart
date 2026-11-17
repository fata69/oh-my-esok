import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../data/account.dart';
import 'theme.dart';

enum _IconTone { blue, copper, violet, teal, rose }

enum MoneyIconSet {
  category,
  wallet;

  List<MoneyIconSpec> get entries => switch (this) {
    category => _categoryIcons,
    wallet => _walletIcons,
  };

  MoneyIconSpec? find(String? id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}

class MoneyIconSpec {
  const MoneyIconSpec._glyph(this.id, this.label, this.glyph, [this._tone])
    : _asset = null;

  const MoneyIconSpec._svg(this.id, this.label, this._asset, [this._tone])
    : glyph = null;

  final String id;
  final String label;
  final IconData? glyph;
  final String? _asset;
  final _IconTone? _tone;
}

// Only these bundled files can be opened for an icon stored in the database.
const _categoryIcons = [
  MoneyIconSpec._svg('makan', 'Makan', 'makan.svg', _IconTone.copper),
  MoneyIconSpec._glyph(
    'mie',
    'Mi',
    Icons.ramen_dining_outlined,
    _IconTone.copper,
  ),
  MoneyIconSpec._glyph('kopi', 'Kopi', Icons.coffee_outlined, _IconTone.teal),
  MoneyIconSpec._svg('minuman', 'Minuman', 'minuman.svg', _IconTone.teal),
  MoneyIconSpec._svg('transport', 'Transport', 'transport.svg', _IconTone.blue),
  MoneyIconSpec._svg('belanja', 'Belanja', 'belanja.svg', _IconTone.violet),
  MoneyIconSpec._svg('tagihan', 'Tagihan', 'tagihan.svg', _IconTone.blue),
  MoneyIconSpec._svg('rumah', 'Rumah', 'rumah.svg', _IconTone.blue),
  MoneyIconSpec._svg('kesehatan', 'Kesehatan', 'kesehatan.svg', _IconTone.rose),
  MoneyIconSpec._svg('hiburan', 'Hiburan', 'hiburan.svg', _IconTone.violet),
  MoneyIconSpec._svg('hewan', 'Hewan', 'hewan.svg', _IconTone.copper),
  MoneyIconSpec._svg('laundry', 'Laundry', 'laundry.svg', _IconTone.blue),
  MoneyIconSpec._svg('olahraga', 'Olahraga', 'olahraga.svg', _IconTone.teal),
  MoneyIconSpec._svg(
    'pendidikan',
    'Pendidikan',
    'pendidikan.svg',
    _IconTone.violet,
  ),
  MoneyIconSpec._svg('pulsa', 'Pulsa', 'pulsa.svg', _IconTone.blue),
  MoneyIconSpec._svg('gaji', 'Gaji', 'gaji.svg', _IconTone.teal),
  MoneyIconSpec._svg('bonus', 'Bonus', 'bonus.svg', _IconTone.teal),
  MoneyIconSpec._glyph(
    'jual',
    'Jual',
    Icons.storefront_outlined,
    _IconTone.teal,
  ),
  MoneyIconSpec._svg('lainnya', 'Lainnya', 'lainnya.svg'),
];

const _walletIcons = [
  MoneyIconSpec._glyph(
    'cash',
    'Tunai',
    Icons.payments_outlined,
    _IconTone.teal,
  ),
  MoneyIconSpec._glyph(
    'bank',
    'Bank',
    Icons.account_balance_outlined,
    _IconTone.blue,
  ),
  MoneyIconSpec._glyph(
    'ewallet',
    'E-wallet',
    Icons.account_balance_wallet_outlined,
    _IconTone.violet,
  ),
  MoneyIconSpec._glyph(
    'card',
    'Kartu',
    Icons.credit_card_outlined,
    _IconTone.copper,
  ),
  MoneyIconSpec._glyph(
    'savings',
    'Tabungan',
    Icons.savings_outlined,
    _IconTone.rose,
  ),
];

const _categoryFallback = MoneyIconSpec._glyph(
  '',
  'Kategori',
  Icons.sell_outlined,
);
const _walletFallback = MoneyIconSpec._glyph(
  '',
  'Sumber dana',
  Icons.account_balance_wallet_outlined,
);

const _defaultCategoryIcons = {
  'cat-exp-makan': 'makan',
  'cat-exp-minuman': 'minuman',
  'cat-exp-transport': 'transport',
  'cat-exp-belanja': 'belanja',
  'cat-exp-tagihan': 'tagihan',
  'cat-exp-kesehatan': 'kesehatan',
  'cat-exp-hiburan': 'hiburan',
  'cat-exp-lain': 'lainnya',
  'cat-inc-gaji': 'gaji',
  'cat-inc-bonus': 'bonus',
  'cat-inc-jual': 'jual',
  'cat-inc-lain': 'lainnya',
};

MoneyIconSpec categoryIconSpec(String? iconId, {String? categoryId}) =>
    MoneyIconSet.category.find(iconId ?? _defaultCategoryIcons[categoryId]) ??
    _categoryFallback;

MoneyIconSpec walletIconSpec(String type, String? iconKey) =>
    MoneyIconSet.wallet.find(iconKey ?? type) ?? _walletFallback;

class MoneyIconGlyph extends StatelessWidget {
  const MoneyIconGlyph({
    super.key,
    required this.spec,
    this.size = 24,
    this.color,
  });

  final MoneyIconSpec spec;
  final double size;
  final Color? color;

  Color _ink(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return color ??
        switch (spec._tone) {
          _IconTone.blue => Color(dark ? 0xFF61A8FF : 0xFF1558D4),
          _IconTone.copper => Color(dark ? 0xFFFF9C54 : 0xFFA84308),
          _IconTone.violet => Color(dark ? 0xFFC4A5FF : 0xFF6A40AC),
          _IconTone.teal => Color(dark ? 0xFF5FCEBA : 0xFF136B60),
          _IconTone.rose => Color(dark ? 0xFFF3A2B2 : 0xFF9D3150),
          null => EsokColors.of(context).muted,
        };
  }

  @override
  Widget build(BuildContext context) {
    final asset = spec._asset;
    final ink = _ink(context);
    return ExcludeSemantics(
      child: asset == null
          ? Icon(spec.glyph!, size: size, color: ink)
          : SvgPicture.asset(
              'assets/icons/categories/$asset',
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              errorBuilder: (_, _, _) =>
                  Icon(Icons.sell_outlined, size: size, color: ink),
            ),
    );
  }
}

class WalletIconView extends StatelessWidget {
  const WalletIconView({
    super.key,
    required this.account,
    this.size = 24,
    this.color,
  });

  final Account account;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => MoneyIconGlyph(
    spec: walletIconSpec(account.type, account.iconKey),
    size: size,
    color: color,
  );
}
