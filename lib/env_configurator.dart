library env_configurator;

import 'dart:io';

import 'package:colorize/colorize.dart';
import 'package:recase/recase.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

class EnvConfigurator {
  Future<void> generate(String configFilePath, String className) async {
    print(Colorize('✓ Info: starting process')..green());

    if (!await Directory('./ios').exists()) {
      print(Colorize('✗ Error: failed to find ios project')..red());
      return;
    }

    if (!await Directory('./android').exists()) {
      print(Colorize('✗ Error: failed to find android project')..red());
      return;
    }

    if (!await File(configFilePath).exists()) {
      print(Colorize(
          '✗ Error: failed to find config file at path $configFilePath')
        ..red());
      return;
    }

    final config = await _loadConfig(configFilePath);
    if (config == null) {
      print(Colorize('✗ Error: failed to parse $configFilePath')..red());
      return;
    }

    final androidNamespace = await _getAndroidNamespace();
    if (androidNamespace == null) {
      print(Colorize('✗ Error: failed to find android package name')..red());
      return;
    }

    final YamlMap? variables = config['variables'];
    if (variables != null) {
      await _generateCodeFiles(className, variables, androidNamespace);
    } else {
      print(Colorize('️⚠ Warning: variables key not found')..yellow());
    }

    final YamlMap? files = config['files'];
    if (files != null) {
      await _copyFiles(files);
    } else {
      print(Colorize('⚠ Warning: files key not found')..yellow());
    }
  }

  /// Load config file
  ///
  ///
  Future<YamlMap?> _loadConfig(String configFileName) async {
    final configFile = File(configFileName);
    final configStr = await configFile.readAsString();
    final config = loadYaml(configStr);
    return config;
  }

  /// Generate code files
  ///
  ///
  Future<void> _generateCodeFiles(
    String className,
    YamlMap variables,
    String androidPackageName,
  ) async {
    await _generateDartFiles(className: className, variables: variables);
    await _generateIosFiles(className: className, variables: variables);
    await _generateAndroidFiles(
      className: className,
      variables: variables,
      androidPackageName: androidPackageName,
    );
  }

  ///
  ///
  ///
  Future<void> _generateDartFiles({
    required String className,
    required YamlMap variables,
  }) async {
    final dartCode = _generateDartCode(className, variables);

    final fileNameReCase = ReCase(className);
    final dartFilePath = './lib/${fileNameReCase.snakeCase}.dart';

    await _writeToFile(dartFilePath, dartCode);
  }

  /// Generate IOS related files
  ///
  ///
  Future<void> _generateIosFiles({
    required String className,
    required YamlMap variables,
  }) async {
    final swiftCode = _generateSwiftCode(className, variables);
    final xcConfigCode = _generateXCConfigCode(variables);
    final pListCode = _generatePListCode(variables);

    final fileNameReCase = ReCase(className);

    final iosFilePath = './ios/Runner/${fileNameReCase.pascalCase}.swift';
    final xcConfigFilePath =
        './ios/Flutter/${fileNameReCase.pascalCase}.xcconfig';
    final pListFilePath = './ios/Runner/${fileNameReCase.pascalCase}.plist';

    await _writeToFile(iosFilePath, swiftCode);
    await _writeToFile(xcConfigFilePath, xcConfigCode);
    await _writeToFile(pListFilePath, pListCode);
  }

  /// Generate Android related files
  ///
  ///
  Future<void> _generateAndroidFiles({
    required String className,
    required YamlMap variables,
    required String androidPackageName,
  }) async {
    final kotlinCode = _generateKotlinCode(
      className,
      variables,
      androidPackageName,
    );
    final xmlCode = _generateXMLResourceCode(variables);

    final fileNameReCase = ReCase(className);

    final androidFilePath =
        './android/app/src/main/kotlin/${androidPackageName.replaceAll('.', '/')}/${fileNameReCase.pascalCase}.kt';
    final androidXMLFilePath =
        './android/app/src/main/res/values/${fileNameReCase.snakeCase}.xml';

    await _writeToFile(androidFilePath, kotlinCode);
    await _writeToFile(androidXMLFilePath, xmlCode);
  }

  /// Write content to given file path
  ///
  ///
  Future<void> _writeToFile(String filePath, String data) async {
    try {
      final f = File(filePath);
      await f.writeAsString(data);
      print(Colorize('✓ Success: generated $filePath')..green());
    } catch (error) {
      print(Colorize('✗ Failed: error generating $filePath')..red());
    }
  }

  /// Copy file from source to target
  ///
  ///
  Future<void> _copyFiles(YamlMap files) async {
    for (final key in files.keys) {
      final keyReCase = ReCase(key);
      try {
        final String srcFilePath = files[key]['source'];
        final String targetFilePath = files[key]['target'];
        final srcFile = File(srcFilePath);
        if (await srcFile.exists()) {
          await srcFile.copy(targetFilePath);
          print(Colorize('✓ Success: ${keyReCase.sentenceCase}')..green());
        } else {
          print(
              Colorize('✗ Failed: ${keyReCase.sentenceCase} - file not exists')
                ..red());
        }
      } catch (error) {
        print(Colorize('✗ Failed: ${keyReCase.sentenceCase}')..red());
      }
    }
  }

  /// Load android gradle file
  ///
  ///
  Future<String?> _getAndroidNamespace() async {
    final gradleFilePath = './android/app/build.gradle';
    final gradleFile = File(gradleFilePath);
    final gradleFileText = await gradleFile.readAsString();

    final regex = RegExp('namespace "(.*?)"');
    final result = regex.firstMatch(gradleFileText);
    if (result != null && result.groupCount > 0) {
      final namespaceLine = result.group(0);
      final packageName =
          namespaceLine?.replaceAll('namespace "', '').replaceAll('"', '');
      return packageName;
    }
    return null;
  }

  ///
  ///
  ///
  String _generateDartCode(String className, YamlMap variables) {
    final formattedClassName = ReCase(className).pascalCase;
    final envConfigBuffer = StringBuffer();

    envConfigBuffer.writeln('class $formattedClassName {');

    for (final key in variables.keys) {
      final vName = ReCase(key).camelCase;
      dynamic value = variables[key];
      envConfigBuffer.writeln('  String get $vName => \'$value\';');
    }

    envConfigBuffer.writeln('}');

    final buffer = StringBuffer();
    buffer.writeln('// This code was generated by a tool');
    buffer.writeln(
        '// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    buffer.writeln();
    buffer.writeln(envConfigBuffer.toString());
    buffer.writeln();

    return buffer.toString();
  }

  ///
  ///
  ///
  String _generateSwiftCode(String className, YamlMap variables) {
    final formattedClassName = ReCase(className).pascalCase;

    final envConfigBuffer = StringBuffer();

    envConfigBuffer.writeln('class $formattedClassName {');

    envConfigBuffer.writeln('    private let config: NSDictionary');
    envConfigBuffer.writeln();
    envConfigBuffer
        .writeln('    init(dictionary: NSDictionary) { config = dictionary }');
    envConfigBuffer.writeln();
    envConfigBuffer.writeln('    convenience init() {');
    envConfigBuffer.writeln('        var nsDictionary: NSDictionary?');
    envConfigBuffer.writeln(
        '        if let path = Bundle.main.path(forResource: "$className", ofType: "plist") {');
    envConfigBuffer.writeln(
        '            nsDictionary = NSDictionary(contentsOfFile: path)');
    envConfigBuffer.writeln('        }');
    envConfigBuffer.writeln('        self.init(dictionary: nsDictionary!)');
    envConfigBuffer.writeln('    }');
    envConfigBuffer.writeln();

    for (final key in variables.keys) {
      final camelCaseKey = ReCase(key).camelCase;
      final constantCaseKey = ReCase(key).constantCase;
      //dynamic value = variables[key];

      envConfigBuffer.writeln(
          '    var $camelCaseKey : String { return config["$constantCaseKey"] as! String }');
    }

    envConfigBuffer.writeln('}');

    final buffer = StringBuffer();
    buffer.writeln('// This code was generated by a tool');
    buffer.writeln(
        '// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    buffer.writeln();
    buffer.writeln(envConfigBuffer.toString());
    buffer.writeln();

    return buffer.toString();
  }

  ///
  ///
  ///
  String _generateXCConfigCode(YamlMap variables) {
    final xcConfigBuffer = StringBuffer();

    for (final key in variables.keys) {
      final reCaseKey = ReCase(key);
      final keyName = reCaseKey.constantCase;
      dynamic value = variables[key];
      if (value is String) {
        value = value.replaceAll('//', '/\$()/');
        xcConfigBuffer.writeln('$keyName=$value');
      } else {
        xcConfigBuffer.writeln('$keyName=$value');
      }
    }

    return xcConfigBuffer.toString();
  }

  ///
  ///
  ///
  String _generatePListCode(YamlMap variables) {
    final envPListBuffer = StringBuffer();

    envPListBuffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    envPListBuffer.writeln(
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">');
    envPListBuffer.writeln('<plist version="1.0">');
    envPListBuffer.writeln('<dict>');

    for (final key in variables.keys) {
      final reCaseKey = ReCase(key);
      final keyName = reCaseKey.constantCase;
      dynamic value = variables[key];

      envPListBuffer.writeln('	<key>$keyName</key>');
      envPListBuffer.writeln('	<string>$value</string>');
    }

    envPListBuffer.writeln('</dict>');
    envPListBuffer.writeln('</plist>');
    return envPListBuffer.toString();
  }

  ///
  ///
  ///
  String _generateKotlinCode(
      String className, YamlMap variables, String packageName) {
    final formattedClassName = ReCase(className).pascalCase;

    final envConfigBuffer = StringBuffer();

    envConfigBuffer.writeln('class $formattedClassName(context: Context) {');
    envConfigBuffer
        .writeln('    private val resources: Resources = context.resources');
    envConfigBuffer.writeln();

    for (final key in variables.keys) {
      final keyReCase = ReCase(key);
      dynamic value = variables[key];
      envConfigBuffer.writeln(
          '    val ${keyReCase.camelCase}: String get() = resources.getString(R.string.${keyReCase.snakeCase})');
    }

    envConfigBuffer.writeln('}');

    final buffer = StringBuffer();
    buffer.writeln('// This code was generated by a tool');
    buffer.writeln(
        '// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    buffer.writeln();
    buffer.writeln('import android.content.Context');
    buffer.writeln('import android.content.res.Resources');
    buffer.writeln('import $packageName.R');
    buffer.writeln();
    buffer.writeln(envConfigBuffer.toString());
    buffer.writeln();

    return buffer.toString();
  }

  ///
  ///
  ///
  String _generateXMLResourceCode(YamlMap variables) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.comment('This code was generated by a tool.');
    builder.comment(
        'Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    builder.element('resources', nest: () {
      for (final key in variables.keys) {
        final keyReCase = ReCase(key);
        dynamic value = variables[key];
        final attributes = {
          'name': keyReCase.snakeCase,
        };

        builder.element('string', attributes: attributes, nest: value);
      }
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }
}
