import 'dart:typed_data';

/// Minimal FIT decoder for `record` messages only (global 20), returned as the same column map
/// the web uploads for members (SHARED_FIELDS in nubisport-astro src/lib/activity-file.ts):
/// timestamp in epoch ms, position in semicircles, distance/altitude in m, speed in m/s.
/// null = not a FIT file, or fewer than 2 timed records.
Map<String, List<num?>>? fitRecordColumns(Uint8List bytes) {
  if (bytes.length < 14 ||
      bytes[0] < 12 ||
      String.fromCharCodes(bytes, 8, 12) != '.FIT') {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  final end = (bytes[0] + data.getUint32(4, Endian.little)).clamp(
    0,
    bytes.length,
  );
  final defs = <int, _Definition>{};
  final rows = <Map<String, num>>[];
  var pos = bytes[0];
  int? lastTimestamp;

  try {
    while (pos < end) {
      final header = bytes[pos++];
      if (header & 0x40 != 0 && header & 0x80 == 0) {
        // Definition message: reserved, architecture, global number, fields (+ developer fields).
        final endian = bytes[pos + 1] == 0 ? Endian.little : Endian.big;
        final global = data.getUint16(pos + 2, endian);
        final count = bytes[pos + 4];
        pos += 5;
        final fields = [
          for (var i = 0; i < count; i++)
            (
              number: bytes[pos + i * 3],
              size: bytes[pos + i * 3 + 1],
              type: bytes[pos + i * 3 + 2],
            ),
        ];
        pos += count * 3;
        var devSize = 0;
        if (header & 0x20 != 0) {
          final devCount = bytes[pos++];
          for (var i = 0; i < devCount; i++) {
            devSize += bytes[pos + i * 3 + 1];
          }
          pos += devCount * 3;
        }
        defs[header & 0x0F] = _Definition(global, endian, fields, devSize);
        continue;
      }

      // Data message: normal header, or compressed timestamp header (5-bit offset on the last timestamp).
      final compressed = header & 0x80 != 0;
      final def = defs[compressed ? (header >> 5) & 0x03 : header & 0x0F];
      if (def == null) break;
      if (compressed && lastTimestamp != null) {
        final offset = header & 0x1F;
        var ts = (lastTimestamp & ~0x1F) + offset;
        if (offset < (lastTimestamp & 0x1F)) ts += 0x20;
        lastTimestamp = ts;
      }
      final row = <String, num>{};
      for (final f in def.fields) {
        final value = _read(data, pos, f.size, f.type, def.endian);
        pos += f.size;
        if (value == null) continue;
        if (f.number == 253) lastTimestamp = value.toInt();
        if (def.global != 20) continue;
        final field = _recordFields[f.number];
        if (field != null) row[field.name] = field.scale(value);
      }
      pos += def.devSize;
      if (def.global != 20) continue;
      final ts =
          row['timestamp'] ??
          (compressed && lastTimestamp != null
              ? (lastTimestamp + _fitEpoch) * 1000
              : null);
      if (ts == null) continue;
      rows.add(row..['timestamp'] = ts);
    }
  } on RangeError {
    // Truncated file: keep the records read so far.
  }

  if (rows.length < 2) return null;
  return {
    for (final name in _columns)
      if (rows.any((r) => r[name] != null))
        name: [for (final r in rows) r[name]],
  };
}

/// Seconds from the Unix epoch to FIT's (1989-12-31 00:00 UTC).
const _fitEpoch = 631065600;

const _columns = [
  'timestamp',
  'positionLat',
  'positionLong',
  'distance',
  'altitude',
  'enhancedAltitude', //
  'speed', 'enhancedSpeed', 'cadence', 'fractionalCadence', 'heartRate',
];

/// Record field number -> column name and the profile's scale/offset.
final _recordFields = <int, ({String name, num Function(num) scale})>{
  253: (name: 'timestamp', scale: (v) => (v + _fitEpoch) * 1000),
  0: (name: 'positionLat', scale: (v) => v),
  1: (name: 'positionLong', scale: (v) => v),
  2: (name: 'altitude', scale: (v) => v / 5 - 500),
  3: (name: 'heartRate', scale: (v) => v),
  4: (name: 'cadence', scale: (v) => v),
  5: (name: 'distance', scale: (v) => v / 100),
  6: (name: 'speed', scale: (v) => v / 1000),
  53: (name: 'fractionalCadence', scale: (v) => v / 128),
  73: (name: 'enhancedSpeed', scale: (v) => v / 1000),
  78: (name: 'enhancedAltitude', scale: (v) => v / 5 - 500),
};

/// First value of a field by FIT base type, or null for the type's "invalid" marker / unknown types.
num? _read(ByteData data, int pos, int size, int type, Endian endian) {
  num? check(int needed, num value, num invalid) =>
      size < needed || value == invalid ? null : value;
  return switch (type & 0x1F) {
    0x00 || 0x02 || 0x0D => check(1, data.getUint8(pos), 0xFF),
    0x01 => check(1, data.getInt8(pos), 0x7F),
    0x0A => check(1, data.getUint8(pos), 0),
    0x03 => check(2, data.getInt16(pos, endian), 0x7FFF),
    0x04 => check(2, data.getUint16(pos, endian), 0xFFFF),
    0x0B => check(2, data.getUint16(pos, endian), 0),
    0x05 => check(4, data.getInt32(pos, endian), 0x7FFFFFFF),
    0x06 => check(4, data.getUint32(pos, endian), 0xFFFFFFFF),
    0x0C => check(4, data.getUint32(pos, endian), 0),
    0x08 => size < 4 ? null : data.getFloat32(pos, endian),
    0x09 => size < 8 ? null : data.getFloat64(pos, endian),
    _ => null,
  };
}

class _Definition {
  _Definition(this.global, this.endian, this.fields, this.devSize);
  final int global;
  final Endian endian;
  final List<({int number, int size, int type})> fields;
  final int devSize;
}
