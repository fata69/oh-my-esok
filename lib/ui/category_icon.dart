import 'package:material_ui/material_ui.dart';

import '../data/category.dart';
import 'money_icon_catalog.dart';

class CategoryIconView extends StatelessWidget {
  const CategoryIconView({
    super.key,
    required this.category,
    this.size = 24,
    this.color,
  });

  final MoneyCategory category;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => MoneyIconGlyph(
    spec: categoryIconSpec(category.iconId, categoryId: category.id),
    size: size,
    color: color,
  );
}
