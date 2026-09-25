/// What a unit measures. Only units of the same kind convert to each other.
/// Declaration order is the order `convert units` lists them in.
enum UnitKind {
  length,
  mass,
  volume,
  time,
  speed,
  temperature,
  area,
  data;

  @override
  String toString() => name;
}

/// One unit. Its value in the kind's base unit is `(value + offset) * factor`;
/// [offset] is only non-zero for temperatures, where zero points differ.
class UnitDef {
  const UnitDef(this.kind, this.names, this.factor, [this.offset = 0]);

  final UnitKind kind;

  /// Every spelling accepted, lowercase. The first is the one listed.
  final List<String> names;
  final double factor;
  final double offset;

  String get symbol => names.first;

  double toBase(double value) => (value + offset) * factor;
  double fromBase(double base) => base / factor - offset;
}

/// Base units: metre, kilogram, litre, second, metre/second, kelvin, square
/// metre, byte. Volumes are US customary (cup, pint, gallon) plus the Swedish
/// kitchen measures `krm`, `tsk`, `msk`; data uses decimal `kb` (1000) and
/// binary `kib` (1024).
const List<UnitDef> allUnits = [
  UnitDef(UnitKind.length, ['mm', 'millimeter', 'millimeters'], 0.001),
  UnitDef(UnitKind.length, ['cm', 'centimeter', 'centimeters'], 0.01),
  UnitDef(UnitKind.length, ['m', 'meter', 'meters', 'metre', 'metres'], 1),
  UnitDef(UnitKind.length, ['km', 'kilometer', 'kilometers'], 1000),
  UnitDef(UnitKind.length, ['in', 'inch', 'inches'], 0.0254),
  UnitDef(UnitKind.length, ['ft', 'foot', 'feet'], 0.3048),
  UnitDef(UnitKind.length, ['yd', 'yard', 'yards'], 0.9144),
  UnitDef(UnitKind.length, ['mi', 'mile', 'miles'], 1609.344),
  UnitDef(UnitKind.length, ['nmi'], 1852),
  UnitDef(UnitKind.mass, ['mg'], 0.000001),
  UnitDef(UnitKind.mass, ['g', 'gram', 'grams'], 0.001),
  UnitDef(UnitKind.mass, ['kg', 'kilo', 'kilos', 'kilogram', 'kilograms'], 1),
  UnitDef(UnitKind.mass, ['t', 'tonne', 'tonnes'], 1000),
  UnitDef(UnitKind.mass, ['oz', 'ounce', 'ounces'], 0.028349523125),
  UnitDef(UnitKind.mass, ['lb', 'lbs', 'pound', 'pounds'], 0.45359237),
  UnitDef(UnitKind.mass, ['st', 'stone'], 6.35029318),
  UnitDef(UnitKind.volume, ['krm'], 0.001),
  UnitDef(UnitKind.volume, ['ml', 'milliliter', 'milliliters'], 0.001),
  UnitDef(UnitKind.volume, ['cl', 'centiliter', 'centiliters'], 0.01),
  UnitDef(UnitKind.volume, ['dl', 'deciliter', 'deciliters'], 0.1),
  UnitDef(UnitKind.volume, ['l', 'liter', 'liters', 'litre', 'litres'], 1),
  UnitDef(UnitKind.volume, ['tsk'], 0.005),
  UnitDef(UnitKind.volume, ['msk'], 0.015),
  UnitDef(UnitKind.volume, ['tsp', 'teaspoon', 'teaspoons'], 0.00492892159375),
  UnitDef(UnitKind.volume, [
    'tbsp',
    'tablespoon',
    'tablespoons',
  ], 0.01478676478125),
  UnitDef(UnitKind.volume, ['floz'], 0.0295735295625),
  UnitDef(UnitKind.volume, ['cup', 'cups'], 0.2365882365),
  UnitDef(UnitKind.volume, ['pt', 'pint', 'pints'], 0.473176473),
  UnitDef(UnitKind.volume, ['gal', 'gallon', 'gallons'], 3.785411784),
  UnitDef(UnitKind.time, ['ms'], 0.001),
  UnitDef(UnitKind.time, ['s', 'sec', 'second', 'seconds'], 1),
  UnitDef(UnitKind.time, ['min', 'minute', 'minutes'], 60),
  UnitDef(UnitKind.time, ['h', 'hr', 'hour', 'hours'], 3600),
  UnitDef(UnitKind.time, ['d', 'day', 'days'], 86400),
  UnitDef(UnitKind.time, ['wk', 'week', 'weeks'], 604800),
  UnitDef(UnitKind.speed, ['m/s'], 1),
  UnitDef(UnitKind.speed, ['km/h', 'kmh', 'kph'], 1 / 3.6),
  UnitDef(UnitKind.speed, ['mph'], 0.44704),
  UnitDef(UnitKind.speed, ['kn', 'knot', 'knots'], 1852 / 3600),
  UnitDef(UnitKind.temperature, ['c', '°c', 'celsius'], 1, 273.15),
  UnitDef(UnitKind.temperature, ['f', '°f', 'fahrenheit'], 5 / 9, 459.67),
  UnitDef(UnitKind.temperature, ['k', 'kelvin'], 1),
  UnitDef(UnitKind.area, ['cm2', 'cm²'], 0.0001),
  UnitDef(UnitKind.area, ['m2', 'm²'], 1),
  UnitDef(UnitKind.area, ['km2', 'km²'], 1000000),
  UnitDef(UnitKind.area, ['ha', 'hectare', 'hectares'], 10000),
  UnitDef(UnitKind.area, ['ft2', 'ft²'], 0.09290304),
  UnitDef(UnitKind.area, ['acre', 'acres'], 4046.8564224),
  UnitDef(UnitKind.data, ['b', 'byte', 'bytes'], 1),
  UnitDef(UnitKind.data, ['kb'], 1000),
  UnitDef(UnitKind.data, ['mb'], 1000000),
  UnitDef(UnitKind.data, ['gb'], 1000000000),
  UnitDef(UnitKind.data, ['tb'], 1000000000000),
  UnitDef(UnitKind.data, ['kib'], 1024),
  UnitDef(UnitKind.data, ['mib'], 1048576),
  UnitDef(UnitKind.data, ['gib'], 1073741824),
  UnitDef(UnitKind.data, ['tib'], 1099511627776),
];

final Map<String, UnitDef> _byName = {
  for (final unit in allUnits)
    for (final name in unit.names) name: unit,
};

/// Looks a unit up by any of its names, ignoring case; null if unknown.
UnitDef? findUnit(String name) => _byName[name.toLowerCase()];

/// Converts [value] between two units of the same kind.
double convertUnits(double value, UnitDef from, UnitDef to) {
  if (from.kind != to.kind) {
    throw ArgumentError('${from.kind} and ${to.kind} do not convert');
  }
  return to.fromBase(from.toBase(value));
}
