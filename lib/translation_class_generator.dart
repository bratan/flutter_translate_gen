﻿import 'package:code_builder/code_builder.dart';
import 'package:flutter_translate_gen/flutter_translate_gen.dart';
import 'package:flutter_translate_gen/json_parser.dart';
import 'package:flutter_translate_gen/localized_item.dart';

class TranslationClassGenerator {
  const TranslationClassGenerator();

  List<Class> generate(
    LocalizedItemBranch root,
    String className,
    FlutterTranslate options,
  ) {
    return _generateClassRecursive(root, className);
  }

  List<Class> _generateClassRecursive(LocalizedItemBranch branch, String name) {
    final classes = <Class>[];
    classes.add(
      Class(
        (cls) => cls
          ..name = name
          ..methods.addAll(branch.leafs.map(_generateLeaf))
          ..methods.addAll(branch.plurals.map(_generateBranchAsPlural))
          ..fields.addAll(branch.branches.map(_generateBranch))
          ..constructors.add(Constructor((c) => c.constant = true)),
      ),
    );
    classes.addAll(
      branch.branches.expand(
        (items) => _generateClassRecursive(items, items.className),
      ),
    );
    return classes;
  }

  Field _generateBranch(LocalizedItemBranch branch) => Field(
        (f) => f
          ..name = branch.camelCasedKey
          ..type = type(branch.className)
          ..modifier = FieldModifier.final$
          ..assignment = "const ${branch.className}()".asCode,
      );

  Method _generateLeaf(LocalizedItemLeaf leaf) {
    final params = leaf.args;
    return params.isEmpty
        ? _generateLeafAsGetter(leaf)
        : _generateLeafAsMethod(leaf, params);
  }

  Method _generateLeafAsGetter(LocalizedItemLeaf leaf) => Method(
        (m) => m
          ..name = leaf.camelCasedKey
          ..returns = stringType
          ..type = MethodType.getter
          ..lambda = true
          ..docs.addAll(leaf.docs)
          ..body = "translate(${leaf.fullPathLiteral})".asCode,
      );

  Method _generateLeafAsMethod(LocalizedItemLeaf leaf, Set<String> args) =>
      Method(
        (m) => m
          ..name = leaf.camelCasedKey
          ..returns = stringType
          ..lambda = true
          ..docs.addAll(leaf.docs)
          ..optionalParameters.addAll(args.asParameters)
          ..body =
              "translate(${leaf.fullPathLiteral}, args: ${args.asMap})".asCode,
      );

  Method _generateBranchAsPlural(LocalizedItemBranch plural) {
    final args = plural.leafs.expand((leaf) => leaf.args).toSet();
    final body = args.isEmpty
        ? "translatePlural(${plural.fullPathLiteral}, value)".asCode
        : "translatePlural(${plural.fullPathLiteral}, value, args: ${args.asMap})"
            .asCode;

    return Method(
      (m) => m
        ..name = plural.camelCasedKey
        ..returns = stringType
        ..lambda = true
        ..docs.addAll(plural.docs)
        ..requiredParameters.add(
          Parameter((p) => p
            ..name = "value"
            ..type = intType),
        )
        ..optionalParameters.addAll(args.asParameters)
        ..body = body,
    );
  }
}

final Reference stringType = type("String");
final Reference intType = type("int");
final Reference dynamicType = type("dynamic");
final Reference requiredAnnotation = type("required");

Reference type(String type) => TypeReference((trb) => trb.symbol = type);

extension on LocalizedItemLeaf {
  List<String> get docs => [
        "/// Translations: ",
        for (final translation in translations.entries)
          "/// * ${translation.key}: ${translation.value}",
        "///",
        "/// parsed from: $fullPath",
      ];
}

extension _Plurals on LocalizedItemBranch {
  List<String> get docs {
    final languages = leafs.expand((leaf) => leaf.translations.keys).toSet();

    final docs = <String>[];
    for (var lang in languages) {
      for (var plural in JsonParser.pluralsKeys) {
        final leaf = this[plural] as LocalizedItemLeaf;
        if (leaf != null) {
          docs.add("/// * $lang:$plural: ${leaf.translations[lang]}");
        }
      }
    }

    return [
      "/// Translations: ",
      ...docs,
      "///",
      "/// parsed from: $fullPath",
    ];
  }
}

extension on String {
  Code get asCode => Code(this);
}

extension on Set<String> {
  String get asMap => "{${map((p) => '"$p": $p').join(",")}}";

  Iterable<Parameter> get asParameters => map((param) => Parameter(
        (p) => p
          ..name = param
          ..type = dynamicType
          ..annotations.add(requiredAnnotation)
          ..named = true,
      ));
}
