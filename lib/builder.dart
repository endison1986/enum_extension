/// Support for doing something awesome.
///
/// More dartdocs go here.
library enum_extension;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/enum_extension_generator.dart';

// TODO: Export any libraries intended for clients of this package.

Builder enumExtension(BuilderOptions options) {
  return SharedPartBuilder([const EnumExtensionGenerator()], 'enum_extension');
}