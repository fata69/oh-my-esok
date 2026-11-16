import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../data/category.dart';
import 'theme.dart';

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
  Widget build(BuildContext context) {
    if (category.iconId != null) {
      return SvgPicture.asset(
        'assets/icons/categories/${category.iconId}.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color ?? EsokColors.ink,
          BlendMode.srcIn,
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          category.name.isEmpty
              ? '?'
              : category.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.58,
            fontWeight: FontWeight.w600,
            color: color ?? EsokColors.ink,
          ),
        ),
      ),
    );
  }
}
