// Runs a fake Home Assistant on http://127.0.0.1:8123 for trying Porch
// without a real server. In Porch's Settings use that address and the token
// "dev".
//
//     dart run tool/fake_ha.dart
import 'dart:io';

import 'fake_ha_server.dart';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8123 : int.parse(args.first);
  final server = FakeHaServer();
  await server.start(port: port);
  stdout.writeln(
    'Fake Home Assistant on http://127.0.0.1:${server.port} (token: dev)',
  );
}
