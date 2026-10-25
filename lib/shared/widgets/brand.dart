import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Brand artwork from the web (nubisport-astro public/brand), picked for the current theme.
/// - [BrandLogo]: symbol + NUBI wordmark (the lockup)
/// - [BrandSymbol]: the N mark alone
/// - [BrandCrest]: the jata (crest roundel)
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => _themed(
    context,
    light: 'assets/brand/nubi-logo.svg',
    dark: 'assets/brand/logo-on-dark.svg',
    height: height,
    label: 'Nubi Sport',
  );
}

class BrandSymbol extends StatelessWidget {
  const BrandSymbol({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => _themed(
    context,
    light: 'assets/brand/nubi-symbol.svg',
    dark: 'assets/brand/symbol-on-dark.svg',
    height: height,
    label: 'Nubi Sport',
  );
}

class BrandCrest extends StatelessWidget {
  const BrandCrest({super.key, this.size = 160});
  final double size;

  @override
  Widget build(BuildContext context) => _themed(
    context,
    light: 'assets/brand/nubi-crest-roundel.svg',
    dark: 'assets/brand/nubi-crest-roundel-reversed.svg',
    height: size,
    label: 'Jata Nubi Sport - Running Community',
  );
}

Widget _themed(
  BuildContext context, {
  required String light,
  required String dark,
  required double height,
  required String label,
}) => SvgPicture.asset(
  Theme.of(context).brightness == Brightness.dark ? dark : light,
  height: height,
  semanticsLabel: label,
);
