import 'dart:io';

// ignore_for_file: avoid_print
void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  final regex = RegExp(r'Icons\.([a-zA-Z0-9_]+)');

  final nonRounded = <String, List<String>>{}; // iconName -> list of files

  for (final file in files) {
    final content = file.readAsStringSync();
    final matches = regex.allMatches(content);

    for (final match in matches) {
      final iconName = match.group(1)!;
      if (!iconName.endsWith('_rounded')) {
        if (!nonRounded.containsKey(iconName)) {
          nonRounded[iconName] = [];
        }
        nonRounded[iconName]!.add(file.path);
      }
    }
  }

  if (nonRounded.isEmpty) {
    print('No non-rounded icons found.');
  } else {
    print('Found non-rounded icons:');
    nonRounded.forEach((name, files) {
      print('$name: ${files.length} occurrences');
      // print('  Examples: ${files.take(3).join(', ')}');
    });
  }
}
