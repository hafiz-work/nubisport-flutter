import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/data/fit_records.dart';

/// Little-endian FIT writer, just enough for the decoder's cases.
class _Fit {
  final _body = BytesBuilder();
  void u8(int v) => _body.addByte(v & 0xFF);
  void u16(int v) => _body.add(
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
  );
  void u32(int v) => _body.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );
  void s32(int v) => _body.add(
    (ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List(),
  );

  void define(
    int local,
    int global,
    List<(int, int, int)> fields, {
    int devSize = 0,
  }) {
    u8(0x40 | (devSize > 0 ? 0x20 : 0) | local);
    u8(0); // reserved
    u8(0); // little endian
    u16(global);
    u8(fields.length);
    for (final (number, size, type) in fields) {
      u8(number);
      u8(size);
      u8(type);
    }
    if (devSize > 0) {
      u8(1);
      u8(0);
      u8(devSize);
      u8(0);
    }
  }

  Uint8List bytes() {
    final body = _body.toBytes();
    final header = ByteData(14)
      ..setUint8(0, 14)
      ..setUint8(1, 0x20)
      ..setUint32(4, body.length, Endian.little);
    final out = header.buffer.asUint8List();
    out.setAll(8, '.FIT'.codeUnits);
    return Uint8List.fromList([...out, ...body, 0, 0]);
  }
}

void main() {
  test('decodes record messages into the web column shape', () {
    const fitStart = 1100000000; // seconds since 1989-12-31
    final fit = _Fit()
      // A non-record message with a developer field: skipped cleanly.
      ..define(2, 21, [(0, 1, 0x00)], devSize: 2)
      ..u8(2)
      ..u8(1)
      ..u16(0xBEEF)
      // record: timestamp, lat, long, distance, enhanced altitude, speed, heart rate
      ..define(0, 20, [
        (253, 4, 0x86),
        (0, 4, 0x85),
        (1, 4, 0x85),
        (5, 4, 0x86),
        (78, 4, 0x86),
        (6, 2, 0x84),
        (3, 1, 0x02),
      ]);
    for (var i = 0; i < 2; i++) {
      fit
        ..u8(0)
        ..u32(fitStart + i * 10)
        ..s32(35791394 + i) // ~3.0 degrees in semicircles
        ..s32(1211012300)
        ..u32(i * 2500) // 25 m
        ..u32((60 + 500) * 5 + i * 5) // 60 m, 61 m
        ..u16(3000) // 3 m/s
        ..u8(i == 0 ? 150 : 0xFF); // second HR is the "invalid" marker
    }
    // Compressed timestamp record (local 1, no timestamp field): last + 5 s.
    final last = fitStart + 10;
    fit
      ..define(1, 20, [(5, 4, 0x86)])
      ..u8(0x80 | (1 << 5) | ((last + 5) & 0x1F))
      ..u32(7500);

    final columns = fitRecordColumns(fit.bytes())!;
    final unixMs = (fitStart + 631065600) * 1000;
    expect(columns['timestamp'], [unixMs, unixMs + 10000, unixMs + 15000]);
    expect(columns['distance'], [0, 25, 75]);
    expect(columns['enhancedAltitude'], [60, 61, null]);
    expect(columns['speed'], [3, 3, null]);
    expect(columns['heartRate'], [150, null, null]);
    expect(columns['positionLat']!.first, 35791394);
    expect(columns.containsKey('cadence'), isFalse);
  });

  test('not a FIT file, or too few records, is null', () {
    expect(fitRecordColumns(Uint8List.fromList(List.filled(20, 0))), isNull);
    final one = _Fit()
      ..define(0, 20, [(253, 4, 0x86)])
      ..u8(0)
      ..u32(1);
    expect(fitRecordColumns(one.bytes()), isNull);
  });
}
