import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
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
      _generateLiteralOf(element, element.fields, _generated);
      _generateIndex(element, element.fields, _generated);
      _generateIndexOf(element, element.fields, _generated);
      _generateEnumValues(element, annotation, element.fields, _generated);
      _generated.writeln('}');
      return _generated.toString();
    } else {
      throw InvalidGenerationSourceError(
        '''@functionalEnum can only be applied on enum types. Instead, you are trying to use is it on a ${element.kind} ${element.name}.''',
        element: element,
      );
    }
  }

  void _generateIndexOf(ClassElement element, List<FieldElement> fields, StringBuffer out) {
    out.writeln('static ${element.name}? indexOf(int index) {');
    out.writeln('switch (index) {');
    var count = 0;
    for (var field in fields) {
      if (checkField(field)) continue;
      out.writeln('case $count:');
      out.writeln('return ${element.name}.${field.name};');
      count++;
    }
    out.writeln('}');
    out.writeln('}');
  }

  void _generateIndex(ClassElement element, List<FieldElement> fields, StringBuffer out) {
    out.writeln('int get index {');
    out.writeln('switch (this) {');
    var count = 0;
    for (var field in fields) {
      if (checkField(field)) continue;
      out.writeln('case ${element.name}.${field.name}:');
      out.writeln('return $count;');
      count++;
    }
    out.writeln('}');
    out.writeln('}');
  }

  void _generateLiteralOf(ClassElement element, List<FieldElement> fields, StringBuffer out) {
    out.writeln('static ${element.name}? literalOf(String literal) {');
    out.writeln('switch (literal) {');
    for (var field in fields) {
      if (checkField(field)) continue;
      out.writeln('case \'${field.name}\':');
      out.writeln('return ${element.name}.${field.name};');
    }
    out.writeln('default:');
    out.writeln('throw ArgumentError();');
    out.writeln('}');
    out.writeln('}');
  }

  void _generateLiteral(ClassElement element, List<FieldElement> fields, StringBuffer out) {
    out.writeln('String get literal {');
    out.writeln('switch (this) {');
    for (var field in fields) {
      if (checkField(field)) continue;
      out.writeln('case ${element.name}.${field.name}:');
      out.writeln('return \'${field.name}\';');
    }
    out.writeln('default:');
    out.writeln('throw ArgumentError();');
    out.writeln('}');
    out.writeln('}');
  }

  String _resolveValue(DartObject? dartObject) {
    if (dartObject == null) {
      return 'null';
    }
    var dartType = dartObject.type;
    if (dartType == null) {
      return 'null';
    }

    if (dartType.isDartCoreString) {
      return '\'${dartObject.toStringValue()}\'';
    } else if (dartType.isDartCoreBool) {
      return '${dartObject.toBoolValue()}';
    } else if (dartType.isDartCoreDouble) {
      return '${dartObject.toDoubleValue()}';
    } else if (dartType.isDartCoreInt) {
      return '${dartObject.toIntValue()}';
    } else {
      return 'null';
    }
  }

  String? _resolveKey(DartObject? dartObject) {
    if (dartObject == null) return null;
    var dartType = dartObject.type;
    if (dartType == null) return null;
    if (!dartType.isDartCoreString) return null;
    return dartObject.toStringValue();
  }

  _generateEnumValues(ClassElement element, ConstantReader annotation, List<FieldElement> fields, StringBuffer out) {
    Map<String, int> defaultValues = {};
    var defaultValuesReader = annotation.read('defaultValues');
    if (!defaultValuesReader.isNull) {
      defaultValuesReader.mapValue.forEach((k, v) {
        var key = _resolveKey(k);
        if (key == null) return;
        defaultValues[key] = v!.toIntValue() ?? 0;
      });
    }
    Map<String, _EnumValueGenerator> enumValueGenerators = {};
    if (defaultValues.isNotEmpty) {
      var count = 0;
      for (var field in fields) {
        if (checkField(field)) continue;
        defaultValues.forEach((key, value) {
          dynamic v;
          if (value == EnumExtension.index) {
            v = '$count';
          } else if (value == EnumExtension.literal) {
            v = '\'${field.name}\'';
          } else {
            return;
          }
          var gen = enumValueGenerators[key];
          if (gen == null) {
            gen = _EnumValueGenerator(key, element);
            enumValueGenerators[key] = gen;
          }
          gen.addValue(field.name, v);
        });
        count++;
      }
    }

    for (var field in fields) {
      if (checkField(field)) continue;
      var annotation = const TypeChecker.fromRuntime(EnumField).firstAnnotationOfExact(field);
      if (annotation != null) {
        var reader = ConstantReader(annotation);
        var valueReader = reader.read('values');
        var map = valueReader.mapValue;
        map.forEach((k, v) {
          var key = _resolveKey(k);
          if (key == null) return;

          var value = _resolveValue(v);
          var gen = enumValueGenerators[key];
          if (gen == null) {
            gen = _EnumValueGenerator(key, element);
            enumValueGenerators[key] = gen;
          }

          gen.addValue(field.name, value);
        });
      }
    }

    for (var element in enumValueGenerators.values) {
      element.write(out);
    }
  }

  bool checkField(FieldElement field) {
    return field.name == 'values' || field.name == 'index';
  }
}

class _EnumValueGenerator {
  final String key;
  final ClassElement element;

  final Map<String, String> valueMapping = {};

  _EnumValueGenerator(this.key, this.element);

  void addValue(String fieldName, String value) {
    valueMapping[fieldName] = value;
  }

  void write(StringBuffer out) {
    out.writeln('dynamic get $key {');
    out.writeln('switch(this) {');
    for (var entry in valueMapping.entries) {
      out.writeln('case ${element.name}.${entry.key}:');
      out.writeln('return ${entry.value};');
    }
    out.writeln('default:');
    out.writeln('return null;');
    out.writeln('}');
    out.writeln('}');
  }
}
