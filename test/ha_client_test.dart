import 'package:flutter_test/flutter_test.dart';

import 'package:porch/ha/ha_client.dart';

import '../tool/fake_ha_server.dart';

Future<void> waitFor(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'timed out waiting');
}

void main() {
  late FakeHaServer server;
  late HaClient client;

  setUp(() async {
    server = FakeHaServer();
    await server.start();
    client = HaClient(retryDelay: const Duration(milliseconds: 50));
  });

  tearDown(() async {
    client.dispose();
    await server.stop();
  });

  test('websocket uri follows the server scheme', () {
    expect(
      HaClient.websocketUri('http://ha.local:8123').toString(),
      'ws://ha.local:8123/api/websocket',
    );
    expect(
      HaClient.websocketUri('https://ha.example.com/').toString(),
      'wss://ha.example.com/api/websocket',
    );
  });

  test('loads states, areas and hides config entities', () async {
    await client.connect('http://127.0.0.1:${server.port}', 'dev');
    await waitFor(() => client.status == HaStatus.connected);

    final lamp = client.entities['light.floor_lamp']!;
    expect(client.areaName(lamp), 'Living room', reason: 'area from device');
    expect(lamp.brightnessPct, 60);
    expect(lamp.stateLabel, 'On at 60%');

    final ids = client.supported.map((e) => e.entityId);
    expect(ids, contains('switch.dehumidifier'));
    expect(ids, isNot(contains('switch.router_led')));
    expect(ids, isNot(contains('sensor.outside_temperature')));
    expect(client.areaName(client.entities['switch.dehumidifier']!), 'Other');
  });

  test('service calls come back as live state changes', () async {
    await client.connect('http://127.0.0.1:${server.port}', 'dev');
    await waitFor(() => client.status == HaStatus.connected);

    await client.setOn(client.entities['switch.tv_power']!, true);
    await waitFor(() => client.entities['switch.tv_power']!.isOn);

    await client.setBrightness(client.entities['light.bedside_lamp']!, 40);
    await waitFor(
      () => client.entities['light.bedside_lamp']!.brightnessPct == 40,
    );

    await client.setOn(client.entities['lock.front_door']!, false);
    await waitFor(
      () => client.entities['lock.front_door']!.stateLabel == 'Unlocked',
    );

    await client.setTemperature(client.entities['climate.thermostat']!, 72);
    await waitFor(
      () => client.entities['climate.thermostat']!.targetTemperature == 72,
    );
  });

  test('a wrong token is reported and not retried', () async {
    await client.connect('http://127.0.0.1:${server.port}', 'nope');
    await waitFor(() => client.status == HaStatus.authFailed);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(client.status, HaStatus.authFailed);
  });

  test('reconnects after the server comes back', () async {
    final port = server.port;
    await client.connect('http://127.0.0.1:$port', 'dev');
    await waitFor(() => client.status == HaStatus.connected);

    await server.stop();
    await waitFor(() => client.status == HaStatus.unreachable);

    server = FakeHaServer();
    await server.start(port: port);
    await waitFor(() => client.status == HaStatus.connected);
  });

  test('no address means not configured', () async {
    await client.connect('', '');
    expect(client.status, HaStatus.notConfigured);
  });
}
