// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  // Regex to capture Icons.NAME
  final regex = RegExp(r'Icons\.([a-zA-Z0-9_]+)');

  // Suffixes to strip before adding _rounded
  final suffixesToRemove = ['_outlined', '_outline', '_sharp', '_filled'];

  for (final file in files) {
    String content = file.readAsStringSync();
    String newContent = content.replaceAllMapped(regex, (match) {
      String name = match.group(1)!;
      String original = match.group(0)!;

      // If already rounded, skip
      if (name.endsWith('_rounded')) {
        return original;
      }

      // If it's a known non-icon property or method, skip (e.g. adaptive)
      // Icons.adaptive is a special case in recent Flutter versions?
      // Actually Icons.adaptive is not in standard stable flutter unless extremely new?
      // But let's check if it is 'adaptive'.
      if (name == 'adaptive') {
        return original;
      }

      // Strip suffixes
      String baseName = name;
      for (final suffix in suffixesToRemove) {
        if (baseName.endsWith(suffix)) {
          baseName = baseName.substring(0, baseName.length - suffix.length);
          break; // Remove only one suffix
        }
      }

      // Append _rounded
      String newName = '${baseName}_rounded';

      return 'Icons.$newName';
    });

    if (content != newContent) {
      print('Updating ${file.path}');
      file.writeAsStringSync(newContent);
    }
  }
  print('Done fixing icons.');
}
