import 'dart:io';

import 'package:xml/xml.dart';

import 'project.dart';

const _derivedKeys = [
  'DaroAppKey',
  'GADApplicationIdentifier',
  'DaroAppLovinSdkKey',
  'DaroAppLovinAdReviewKey',
];

String? _string(XmlDocument document, String name) {
  final keys = document
      .getElement('plist')
      ?.getElement('dict')
      ?.findElements('key')
      .where((key) => key.innerText == name)
      .toList();
  if (keys == null || keys.length != 1) return null;
  final value = keys.single.nextElementSibling;
  return value?.name.local == 'string' && value!.innerText.isNotEmpty
      ? value.innerText
      : null;
}

/// Decrypt only in a temporary plist; never expose native tool output or keys.
Future<List<String>> checkIosKeys(
  SetupPlan plan, {
  Future<ProcessResult> Function(String, List<String>) run = Process.run,
}) async {
  final tool = plan.file('ios/Pods/DaroAds/Scripts/daro');
  if (!tool.existsSync()) {
    return [
      'iOS key verification tool is missing. Run configure on macOS to install DaroAds pods.',
    ];
  }
  Directory? temporary;
  try {
    const path = 'ios/Runner/Info.plist';
    final actual = XmlDocument.parse(plan.read(path));
    // Planned content carries the current daro.yaml key even before configure.
    final desired = XmlDocument.parse(plan.changes[path] ?? plan.read(path));
    final key = _string(desired, 'DaroIntegrationKey');
    if (key == null) {
      return ['iOS Integration Key is missing. Run configure.'];
    }
    final input = XmlDocument.parse(
      '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>',
    );
    setPlistString(
      input.getElement('plist')!.getElement('dict')!,
      'DaroIntegrationKey',
      key,
    );
    temporary = await Directory.systemTemp.createTemp('daro-doctor-');
    final plist = File('${temporary.path}/Info.plist');
    await plist.writeAsString(input.toXmlString());
    final result = await run(
      tool.absolute.path,
      ['platform-key', '--plist', plist.path, '--inject'],
    );
    if (result.exitCode != 0) {
      return [
        'iOS Integration Key decryption failed. Check daro.yaml and run configure.',
      ];
    }
    final expected = XmlDocument.parse(await plist.readAsString());
    final problems = <String>[];
    for (final name in _derivedKeys) {
      final decoded = _string(expected, name);
      final installed = _string(actual, name);
      if (decoded == null) {
        problems.add(
            'iOS key verification tool did not produce $name. Reinstall DaroAds pods.',);
      } else if (installed == null) {
        problems.add('iOS $name is missing or invalid. Run configure.');
      } else if (installed != decoded) {
        problems.add(
            'iOS $name does not match the current Integration Key. Run configure.',);
      }
    }
    return problems;
  } on Exception {
    return [
      'Could not verify iOS derived keys. Check DaroAds tool permissions and plist syntax, then run configure.',
    ];
  } finally {
    if (temporary != null) await temporary.delete(recursive: true);
  }
}
