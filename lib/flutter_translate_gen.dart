import 'dart:async';
import 'dart:convert';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_casing/dart_casing.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dart_utils/dart_utils.dart';
import 'package:flutter_translate_annotations/flutter_translate_annotations.dart';
import 'package:flutter_translate_gen/annotation_generator.dart';
import 'package:flutter_translate_gen/keys_class_generator.dart';
import 'package:flutter_translate_gen/localized_item.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

class FlutterTranslateGen extends AnnotationGenerator<TranslateKeysOptions> {
  static List<String>? reservedKeys = const ["0", "1", "else"];

  const FlutterTranslateGen();

  @override
  Future<String?> generateForAnnotatedElement(
      Element? element, ConstantReader? annotation, BuildStep? buildStep) async {
    validateClass(element!);

    final options = parseOptions(annotation!);

    var className = element.name;

    validateClassName(className!);

    List<LocalizedItem>? translations;

    try {
      translations = await getKeyMap(buildStep, options);
    } on FormatException catch (_) {
      throw InvalidGenerationSourceError("Ths JSON format is invalid.");
    }

    final file =
        Library((lb) => lb..body.addAll([KeysClassGenerator.generateClass(options!, translations!, className)]));

    final DartEmitter emitter = DartEmitter(allocator: Allocator.none);

    return DartFormatter().format('${file.accept(emitter)}');
  }

  TranslateKeysOptions? parseOptions(ConstantReader? annotation) {
    return TranslateKeysOptions(
        path: annotation!.peek("path")!.stringValue,
        caseStyle: enumFromString(CaseStyle.values, annotation.peek("caseStyle")!.revive().accessor),
        separator: annotation.peek("separator")!.stringValue);
  }

  Future<List<LocalizedItem>?> getKeyMap(BuildStep? step, TranslateKeysOptions? options) async {
    Map<String, List<String>>? mapping = <String, List<String>>{};

    final List<AssetId>? assets = await step!.findAssets(Glob(options!.path, recursive: true)).toList();

    for (final AssetId entity in assets!) {
      Map<String, dynamic>? jsonMap = json.decode(await step.readAsString(entity));

      final Map<String, String>? translationMap = getTranslationMap(jsonMap);

      translationMap!.forEach((String? key, String? value) => (mapping[key!] ??= <String>[]).add(value!));
    }

    List<LocalizedItem>? translations = [];

    mapping.forEach((id, trans) => translations.add(LocalizedItem(id, trans, getKeyFieldName(id, options)!)));

    return translations;
  }

  String? getKeyFieldName(String? key, TranslateKeysOptions? options) {
    switch (options!.caseStyle) {
      case CaseStyle.titleCase:
        return Casing.titleCase(key!, separator: options.separator);
      case CaseStyle.upperCase:
        return Casing.upperCase(key!, separator: options.separator);
      case CaseStyle.lowerCase:
        return Casing.lowerCase(key!, separator: options.separator);
      default:
        return throw InvalidGenerationSourceError("Invalid CaseStyle specified: ${options.caseStyle.toString()}");
    }
  }

  Map<String, String>? getTranslationMap(Map<String, dynamic>? jsonMap, {String? parentKey}) {
    final Map<String, String>? map = Map<String, String>();

    for (final String? entry in jsonMap!.keys) {
      String? key;

      if (reservedKeys!.contains(entry)) {
        key = parentKey;
      } else {
        key = parentKey != null ? "$parentKey.$entry" : entry;
      }

      if (key == null) continue;

      var value = jsonMap[entry];

      if (value is String) {
        map!.putIfAbsent(key, () => value);
      } else {
        var entries = getTranslationMap(value, parentKey: key);

        map!.addAll(entries!);
      }
    }

    return map;
  }

  void validateClassName(String? className) {
    if (!className!.startsWith("_\$")) {
      throw InvalidGenerationSourceError(
          "The annotated class name (currently '$className') must start with _\$. For example _\$Keys or _\$LocalizationKeys");
    }
  }

  void validateClass(Element? element) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          "The annotated element is not a Class! TranslateKeyOptions should be used on Classes.",
          element: element);
    }
  }
}
