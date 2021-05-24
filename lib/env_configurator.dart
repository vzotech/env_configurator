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

    final manifestXML = await _readAndroidManifestFile();
    final androidPackageName = _getPackageName(manifestXML);
    if (androidPackageName == null) {
      print(Colorize('✗ Error: failed to find android package name')..red());
      return;
    }

    final YamlMap? variables = config['variables'];
    if (variables != null) {
      await _generateCodeFiles(className, variables, androidPackageName);
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
      String className, YamlMap variables, String androidPackageName) async {
    final dartCode = _generateDartCode(className, variables);

    final swiftCode = _generateSwiftCode(className, variables);
    final xcConfigCode = _generateXCConfigCode(variables);
    final pListCode = _generatePListCode(variables);

    final kotlinCode =
        _generateKotlinCode(className, variables, androidPackageName);
    final xmlCode = _generateXMLResourceCode(variables);

    final fileNameReCase = ReCase(className);
    final dartFilePath = './lib/${fileNameReCase.snakeCase}.dart';

    final iosFilePath = './ios/Runner/${fileNameReCase.pascalCase}.swift';
    final xcConfigFilePath =
        './ios/Flutter/${fileNameReCase.pascalCase}.xcconfig';
    final pListFilePath = './ios/Runner/${fileNameReCase.pascalCase}.plist';

    final androidFilePath =
        './android/app/src/main/kotlin/${androidPackageName.replaceAll('.', '/')}/${fileNameReCase.pascalCase}.kt';
    final androidXMLFilePath =
        './android/app/src/main/res/values/${fileNameReCase.snakeCase}.xml';

    await _writeToFile(dartFilePath, dartCode);

    await _writeToFile(iosFilePath, swiftCode);
    await _writeToFile(xcConfigFilePath, xcConfigCode);
    await _writeToFile(pListFilePath, pListCode);

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

  /// Load android manifest file
  ///
  ///
  Future<XmlDocument> _readAndroidManifestFile() async {
    final manifestFilePath = './android/app/src/main/AndroidManifest.xml';
    final manifestFile = File(manifestFilePath);
    final manifestText = await manifestFile.readAsString();
    final manifestXML = XmlDocument.parse(manifestText);
    return manifestXML;
  }

  /// Get package name from manifest file
  ///
  ///
  String? _getPackageName(XmlDocument manifestXML) {
    final manifestElements = manifestXML.findElements('manifest');
    if (manifestElements.length == 1) {
      final manifest = manifestElements.first;
      for (final attribute in manifest.attributes) {
        if (attribute.name.toString() == 'package') {
          return attribute.value;
        }
      }
    }

    return null;
  }

  ///
  ///
  ///
  String _generateDartCode(String className, YamlMap variables) {
    final formattedClassName = ReCase(className).pascalCase;
    final envConfigBuffer = StringBuffer();
    final envConfigBufferImpl = StringBuffer();

    envConfigBuffer.writeln('abstract class $formattedClassName {');
    envConfigBufferImpl.writeln(
        'class ${formattedClassName}Impl extends $formattedClassName {');

    for (final key in variables.keys) {
      final vName = ReCase(key).camelCase;
      dynamic value = variables[key];
      if (value is String) {
        envConfigBuffer.writeln('  String get $vName;');
        envConfigBufferImpl
            .writeln('  @override String get $vName => \'$value\';');
      } else if (value is bool) {
        envConfigBuffer.writeln('  bool get $vName;');
        envConfigBufferImpl.writeln('  @override bool get $vName => $value;');
      } else if (value is int) {
        envConfigBuffer.writeln('  int get $vName;');
        envConfigBufferImpl.writeln('  @override int get $vName => $value;');
      } else if (value is double) {
        envConfigBuffer.writeln('  double get $vName;');
        envConfigBufferImpl.writeln('  @override double get $vName => $value;');
      } else {
        envConfigBuffer.writeln('  String get $vName;');
        envConfigBufferImpl
            .writeln('  @override String get $vName => \'$value\';');
      }
    }

    envConfigBuffer.writeln('}');
    envConfigBufferImpl.writeln('}');

    final buffer = StringBuffer();
    buffer.writeln('// This code was generated by a tool');
    buffer.writeln(
        '// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    buffer.writeln();
    buffer.writeln(envConfigBuffer.toString());
    buffer.writeln();
    buffer.writeln(envConfigBufferImpl.toString());
    buffer.writeln();

    return buffer.toString();
  }

  ///
  ///
  ///
  String _generateSwiftCode(String className, YamlMap variables) {
    final formattedClassName = ReCase(className).pascalCase;

    final envConfigBuffer = StringBuffer();
    final envConfigBufferImpl = StringBuffer();

    envConfigBuffer.writeln('protocol $formattedClassName {');

    envConfigBufferImpl
        .writeln('class ${formattedClassName}Impl : $formattedClassName {');
    envConfigBufferImpl.writeln('    private let config: NSDictionary');
    envConfigBufferImpl.writeln();
    envConfigBufferImpl
        .writeln('    init(dictionary: NSDictionary) { config = dictionary }');
    envConfigBufferImpl.writeln();
    envConfigBufferImpl.writeln('    convenience init() {');
    envConfigBufferImpl.writeln('        var nsDictionary: NSDictionary?');
    envConfigBufferImpl.writeln(
        '        if let path = Bundle.main.path(forResource: "$className", ofType: "plist") {');
    envConfigBufferImpl.writeln(
        '            nsDictionary = NSDictionary(contentsOfFile: path)');
    envConfigBufferImpl.writeln('        }');
    envConfigBufferImpl.writeln('        self.init(dictionary: nsDictionary!)');
    envConfigBufferImpl.writeln('    }');
    envConfigBufferImpl.writeln();

    for (final key in variables.keys) {
      final camelCaseKey = ReCase(key).camelCase;
      final constantCaseKey = ReCase(key).constantCase;
      dynamic value = variables[key];

      if (value is String) {
        envConfigBuffer.writeln('    var $camelCaseKey : String { get }');
        envConfigBufferImpl.writeln(
            '    var $camelCaseKey : String { return config["$constantCaseKey"] as! String }');
      } else if (value is bool) {
        envConfigBuffer.writeln('    var $camelCaseKey : Bool { get }');
        envConfigBufferImpl.writeln(
            '    var $camelCaseKey : Bool { return config["$constantCaseKey"] as! Bool }');
      } else if (value is int) {
        envConfigBuffer.writeln('    var $camelCaseKey : Int { get }');
        envConfigBufferImpl.writeln(
            '    var $camelCaseKey : Int { return config["$constantCaseKey"] as! Int }');
      } else if (value is double) {
        envConfigBuffer.writeln('    var $camelCaseKey : Double { get }');
        envConfigBufferImpl.writeln(
            '    var $camelCaseKey : Double { return config["$constantCaseKey"] as! Double }');
      } else {
        envConfigBuffer.writeln('    var $camelCaseKey : String { get }');
        envConfigBufferImpl.writeln(
            '    var $camelCaseKey : String { return config["$constantCaseKey"] as! String }');
      }
    }

    envConfigBuffer.writeln('}');
    envConfigBufferImpl.writeln('}');

    final buffer = StringBuffer();
    buffer.writeln('// This code was generated by a tool');
    buffer.writeln(
        '// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    buffer.writeln();
    buffer.writeln(envConfigBuffer.toString());
    buffer.writeln();
    buffer.writeln(envConfigBufferImpl.toString());
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

      if (value is String) {
        envPListBuffer.writeln('	<string>\$($keyName)</string>');
      } else if (value is bool) {
        envPListBuffer.writeln(value ? '	<true/>' : '	<false/>');
      } else if (value is int) {
        envPListBuffer.writeln('	<integer>\$($keyName)</integer>');
      } else if (value is double) {
        envPListBuffer.writeln('	<real>\$($keyName)</real>');
      } else {
        envPListBuffer.writeln('	<string>\$($keyName)</string>');
      }
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
    final envConfigResourceBuffer = StringBuffer();

    envConfigBuffer.writeln('abstract class $formattedClassName {');

    envConfigResourceBuffer.writeln(
        'class ${formattedClassName}Resources : $formattedClassName() {');
    envConfigResourceBuffer.writeln(
        '    private val resources: Resources = Resources.getSystem()');
    envConfigResourceBuffer.writeln();

    for (final key in variables.keys) {
      final keyReCase = ReCase(key);
      dynamic value = variables[key];
      if (value is String) {
        envConfigBuffer
            .writeln('    abstract val ${keyReCase.camelCase}: String');
        envConfigResourceBuffer.writeln(
            '    override val ${keyReCase.camelCase}: String get() = resources.getString(R.string.${keyReCase.snakeCase})');
      } else if (value is bool) {
        envConfigBuffer
            .writeln('    abstract val ${keyReCase.camelCase}: Boolean');
        envConfigResourceBuffer.writeln(
            '    override val ${keyReCase.camelCase}: Boolean get() = resources.getBoolean(R.bool.${keyReCase.snakeCase})');
      } else if (value is int) {
        envConfigBuffer.writeln('    abstract val ${keyReCase.camelCase}: Int');
        envConfigResourceBuffer.writeln(
            '    override val ${keyReCase.camelCase}: Int get() = resources.getInteger(R.integer.${keyReCase.snakeCase})');
      } else if (value is double) {
        envConfigBuffer
            .writeln('    abstract val ${keyReCase.camelCase}: Float');
        envConfigResourceBuffer.writeln(
            '    override val ${keyReCase.camelCase}: Float get() = resources.getFraction(R.fraction.${keyReCase.snakeCase}, 1, 1)');
      } else {
        envConfigBuffer
            .writeln('    abstract val ${keyReCase.camelCase}: String');
        envConfigResourceBuffer.writeln(
            '    override val ${keyReCase.camelCase}: String get() = resources.getString(R.string.${keyReCase.snakeCase})');
      }
    }

    envConfigBuffer.writeln('}');
    envConfigResourceBuffer.writeln('}');

    final buffer = StringBuffer();
    buffer.writeln('// This code was generated by a tool');
    buffer.writeln(
        '// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated');
    buffer.writeln();
    buffer.writeln('import android.content.res.Resources');
    buffer.writeln('import $packageName.R');
    buffer.writeln();
    buffer.writeln(envConfigBuffer.toString());
    buffer.writeln();
    buffer.writeln(envConfigResourceBuffer.toString());
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

        if (value is String) {
          builder.element('string', attributes: attributes, nest: value);
        } else if (value is bool) {
          builder.element('bool', attributes: attributes, nest: value);
        } else if (value is int) {
          builder.element('integer', attributes: attributes, nest: value);
        } else if (value is double) {
          builder.element('fraction', attributes: attributes, nest: value);
        } else {
          builder.element('string', attributes: attributes, nest: value);
        }
      }
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }
}
