import 'package:build/build.dart';
import 'package:flutter_translate_gen/flutter_translate_gen.dart';
import 'package:source_gen/source_gen.dart';

Builder staticKeysBuilder(BuilderOptions options)
{
    return SharedPartBuilder([FlutterTranslateGen()], 'static_keys_generator');
}
