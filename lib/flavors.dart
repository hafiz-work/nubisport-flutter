enum Flavor {
  dev,
  prod,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Nubi Sport Dev';
      case Flavor.prod:
        return 'Nubi Sport';
    }
  }

}
