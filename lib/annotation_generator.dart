import 'dart:async';
import 'package:async/async.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

abstract class AnnotationGenerator<T> extends Generator {
  const AnnotationGenerator();

  TypeChecker? get typeChecker => TypeChecker.fromRuntime(T);

  @override
  FutureOr<String>? generate(LibraryReader? library, BuildStep? buildStep) async {
    final values = Set<String>();

    for (final AnnotatedElement annotatedElement in library!.annotatedWith(typeChecker!)) {
      final generatedValue =
          generateForAnnotatedElement(annotatedElement.element, annotatedElement.annotation, buildStep!);

      final Stream<String>? output = normalizeGeneratorOutput(generatedValue);
      await for (final String value in output!) {
        assert((value.length == value.trim().length));

        values.add(value);
      }
    }

    return values.join('\n\n');
  }

  dynamic generateForAnnotatedElement(Element? element, ConstantReader? annotation, BuildStep? buildStep);

  Stream<String> normalizeGeneratorOutput(Object? value) {
    if (value == null) {
      return const Stream.empty();
    } else if (value is Future) {
      return StreamCompleter.fromFuture(value.then(normalizeGeneratorOutput));
    } else if (value is String?) {
      value = [value];
    }

    if (value is Iterable?) {
      value = Stream.fromIterable(value as Iterable);
    }

    if (value is Stream) {
      return value.where((e) => e != null).map((e) {
        if (e is String?) {
          return e!.trim();
        }

        throw _argError(e)!;
      }).where((e) => e.isNotEmpty);
    }

    throw _argError(value)!;
  }

  ArgumentError? _argError(Object? value) => ArgumentError(
      'Must be a String or be an Iterable/Stream containing String values. Found `${Error.safeToString(value)}` (${value.runtimeType}).');
}
