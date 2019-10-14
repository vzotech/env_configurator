import 'package:env_configurator/env_configurator.dart';
import 'package:args/args.dart';

main(List<String> arguments) async {
  final parser = ArgParser();

  parser.addOption('file', abbr: 'f', defaultsTo: './env_config.yaml');
  parser.addOption('env', abbr: 'e', defaultsTo: 'dev');
  parser.addOption('className', abbr: 'c', defaultsTo: 'EnvConfig');

  final results = parser.parse(arguments);

  final filePath = results['file'];
  final env = results['env'];
  final className = results['className'];

  final configGenerator = EnvConfigurator();
  await configGenerator.generate(filePath, env, className);
}
