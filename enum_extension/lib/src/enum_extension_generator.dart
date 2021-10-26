import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:enum_extension_annotation/enum_extension_annotation.dart';
import 'package:source_gen/source_gen.dart';

class EnumExtensionGenerator extends GeneratorForAnnotation<EnumExtension> {
  const EnumExtensionGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element.kind == ElementKind.ENUM && element is ClassElement) {
      final _generated = StringBuffer();
      _generated.writeln('extension ${element.name}Extension on ${element.name} {');
      _generateLiteral(element, element.fields, _generated);
      _generated.writeln('}');
      return _generated.toString();
    } else {
      throw InvalidGenerationSourceError(
        '''@functionalEnum can only be applied on enum types. Instead, you are trying to use is it on a ${element.kind} ${element.name}.''',
        element: element,
      );
    }
  }

  void _generateLiteral(ClassElement element, List<FieldElement> fields, StringBuffer out) {
    out.writeln('String get literal {');
    out.writeln('switch (this) {');
    for (var field in fields) {
      final annotation = const TypeChecker.fromRuntime(EnumValue).firstAnnotationOfExact(field);
      out.writeln('case ${element.name}.${field.name}:');
      dynamic literalValue;
      if (annotation == null) {
        literalValue = field.name;
      } else {
        final reader = ConstantReader(annotation);
        final valueReader = reader.read('value');
        literalValue = !valueReader.isNull ? valueReader.stringValue : field.name;
      }
      out.writeln('return $literalValue;');
    }
    out.writeln('default:');
    out.writeln('throw ArgumentError();');
    out.writeln('}');
    out.writeln('}');
  }
}
