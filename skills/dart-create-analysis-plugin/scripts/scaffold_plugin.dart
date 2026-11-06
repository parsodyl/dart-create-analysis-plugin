#!/usr/bin/env dart

import 'dart:io';

String toPascalCase(String snakeStr) {
  return snakeStr
      .split('_')
      .where((s) => s.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join();
}

void printHelp() {
  stdout.writeln('''
Scaffold a modern Dart analysis_server_plugin package (Dart 3.10+ / Flutter 3.38+).

Usage:
  dart scripts/scaffold_plugin.dart --name <pkg_name> [options]

Options:
  --name <name>            Package name in snake_case (required, e.g. company_lints)
  --output-dir <dir>       Directory to scaffold into (defaults to ./<name>)
  --rule <rule_name>       Sample rule name in snake_case (defaults to avoid_empty_catch)
  --description <text>     Package description in pubspec.yaml
  -h, --help               Show this help message
''');
}

void main(List<String> args) {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    printHelp();
    exit(args.isEmpty ? 64 : 0);
  }

  String? pkgName;
  String? outputDir;
  var ruleName = 'avoid_empty_catch';
  var description = 'Custom static analysis rules, fixes, and assists.';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--name' && i + 1 < args.length) {
      pkgName = args[++i];
    } else if (arg.startsWith('--name=')) {
      pkgName = arg.substring('--name='.length);
    } else if (arg == '--output-dir' && i + 1 < args.length) {
      outputDir = args[++i];
    } else if (arg.startsWith('--output-dir=')) {
      outputDir = arg.substring('--output-dir='.length);
    } else if (arg == '--rule' && i + 1 < args.length) {
      ruleName = args[++i];
    } else if (arg.startsWith('--rule=')) {
      ruleName = arg.substring('--rule='.length);
    } else if (arg == '--description' && i + 1 < args.length) {
      description = args[++i];
    } else if (arg.startsWith('--description=')) {
      description = arg.substring('--description='.length);
    } else {
      stderr.writeln('Unknown argument: $arg');
      printHelp();
      exit(64);
    }
  }

  if (pkgName == null || pkgName.trim().isEmpty) {
    stderr.writeln('Error: Missing required option --name.');
    printHelp();
    exit(64);
  }

  pkgName = pkgName.trim().toLowerCase();
  ruleName = ruleName.trim().toLowerCase();

  final validNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
  if (!validNamePattern.hasMatch(pkgName)) {
    stderr.writeln(
      'Error: Invalid package name "$pkgName". Must be snake_case.',
    );
    exit(1);
  }
  if (!validNamePattern.hasMatch(ruleName)) {
    stderr.writeln('Error: Invalid rule name "$ruleName". Must be snake_case.');
    exit(1);
  }

  final ruleClass = toPascalCase(ruleName);
  final pluginClass = '${toPascalCase(pkgName)}Plugin';

  final targetDir = Directory(outputDir ?? pkgName).absolute;
  stdout.writeln('Scaffolding modern Dart analysis plugin "$pkgName" into:');
  stdout.writeln('  ${targetDir.path}\n');

  Directory('${targetDir.path}/lib/src/rules').createSync(recursive: true);
  Directory('${targetDir.path}/lib/src/fixes').createSync(recursive: true);
  Directory('${targetDir.path}/lib/src/assists').createSync(recursive: true);
  Directory('${targetDir.path}/test').createSync(recursive: true);

  // 1. pubspec.yaml
  File('${targetDir.path}/pubspec.yaml').writeAsStringSync('''name: $pkgName
description: $description
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.10.0

dependencies:
  analysis_server_plugin: ^0.3.0
  analyzer: '>=8.0.0 <20.0.0'
  analyzer_plugin: '>=0.13.0 <1.0.0'

dev_dependencies:
  analyzer_testing: ^0.4.0
  lints: '>=5.0.0 <7.0.0'
  test: ^1.25.0
  test_reflective_loader: ^0.6.0
''');

  // 2. analysis_options.yaml
  File('${targetDir.path}/analysis_options.yaml').writeAsStringSync(
    '''# Minimal analysis options for the plugin package itself
include: package:lints/recommended.yaml
''',
  );

  // 3. lib/main.dart
  File('${targetDir.path}/lib/main.dart').writeAsStringSync(
    '''import 'dart:async';
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/assists/wrap_with_try_catch_assist.dart';
import 'src/fixes/${ruleName}_fix.dart';
import 'src/rules/$ruleName.dart';

final plugin = $pluginClass();

class $pluginClass extends Plugin {
  @override
  String get name => '$pkgName';

  @override
  FutureOr<void> register(PluginRegistry registry) {
    // 1. Warning Rule (enabled by default when plugin is referenced)
    registry.registerWarningRule($ruleClass());

    // 2. Quick Fix for the rule
    registry.registerFixForRule($ruleClass.code, ${ruleClass}Fix.new);

    // 3. Contextual Quick Assist
    registry.registerAssist(WrapWithTryCatchAssist.new);
  }
}
''',
  );

  // 4. lib/src/rules/<rule_name>.dart
  File('${targetDir.path}/lib/src/rules/$ruleName.dart').writeAsStringSync(
    '''import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class $ruleClass extends AnalysisRule {
  static const LintCode code = LintCode(
    '$ruleName',
    'Catch clauses should not be empty.',
    correctionMessage: 'Rethrow or handle the caught error.',
    uniqueName: 'LintCode.$ruleName',
  );

  $ruleClass()
    : super(
        name: '$ruleName',
        description: 'Catches should handle or rethrow the error.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addCatchClause(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitCatchClause(CatchClause node) {
    final body = node.body;
    if (body.statements.isEmpty) {
      rule.reportAtToken(
        node.catchKeyword ?? node.onKeyword ?? node.beginToken,
      );
    }
  }
}
''',
  );

  // 5. lib/src/fixes/<rule_name>_fix.dart
  File(
    '${targetDir.path}/lib/src/fixes/${ruleName}_fix.dart',
  ).writeAsStringSync(
    '''import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class ${ruleClass}Fix extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    '$pkgName.fix.$ruleName',
    DartFixKindPriority.standard,
    'Add rethrow in catch clause',
  );

  ${ruleClass}Fix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final catchClause = node.thisOrAncestorOfType<CatchClause>();
    if (catchClause == null) return;

    final body = catchClause.body;
    await builder.addDartFileEdit(file, (fileBuilder) {
      fileBuilder.addInsertion(body.leftBracket.end, (editBuilder) {
        editBuilder.writeln();
        editBuilder.write('    rethrow;');
      });
    });
  }
}
''',
  );

  // 6. lib/src/assists/wrap_with_try_catch_assist.dart
  File(
    '${targetDir.path}/lib/src/assists/wrap_with_try_catch_assist.dart',
  ).writeAsStringSync(
    '''import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class WrapWithTryCatchAssist extends ResolvedCorrectionProducer {
  static const _assistKind = AssistKind(
    '$pkgName.assist.wrap_with_try_catch',
    30,
    'Wrap statement in try-catch block',
  );

  WrapWithTryCatchAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final statement = node.thisOrAncestorOfType<Statement>();
    if (statement == null || statement is Block) return;

    final statementText = utils.getNodeText(statement);

    await builder.addDartFileEdit(file, (fileBuilder) {
      fileBuilder.addReplacement(range.node(statement), (editBuilder) {
        editBuilder.writeln('try {');
        editBuilder.write('  ');
        editBuilder.writeln(statementText);
        editBuilder.writeln('} catch (e, stackTrace) {');
        editBuilder.writeln('  rethrow;');
        editBuilder.write('}');
      });
    });
  }
}
''',
  );

  // 7. test/<rule_name>_test.dart
  File('${targetDir.path}/test/${ruleName}_test.dart').writeAsStringSync(
    '''// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:$pkgName/src/rules/$ruleName.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(${ruleClass}Test);
  });
}

@reflectiveTest
class ${ruleClass}Test extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = $ruleClass();
    super.setUp();
  }

  Future<void> test_catchWithBody_noDiagnostic() async {
    await assertNoDiagnostics(r\'\'\'
void foo() {
  try {
    throw Exception();
  } catch (e) {
    rethrow;
  }
}
\'\'\');
  }

  Future<void> test_emptyCatch_reportsDiagnostic() async {
    await assertDiagnostics(
      r\'\'\'
void foo() {
  try {
    throw Exception();
  } catch (e) {}
}
\'\'\',
      [
        lint(48, 5), // 'catch'
      ],
    );
  }
}
''',
  );

  // 8. README.md
  File('${targetDir.path}/README.md').writeAsStringSync('''# $pkgName

A custom Dart static analysis plugin built with the official `analysis_server_plugin` architecture (Dart 3.10+ / Flutter 3.38+).

## Activation

In the root `analysis_options.yaml` of your target app:

```yaml
plugins:
  $pkgName:
    path: path/to/$pkgName
```

## Included Rules & Features
- **`$ruleName`**: Warns on empty catch blocks.
- **Quick Fix**: Automatically inserts `rethrow;` into empty catch blocks.
- **Quick Assist**: Context action to wrap statements in `try-catch`.

## Running Tests

```bash
dart pub get
dart test
```
''');

  stdout.writeln('Success! Package "$pkgName" created at ${targetDir.path}.');
  stdout.writeln('\nNext steps:');
  stdout.writeln('  1. cd ${targetDir.path}');
  stdout.writeln('  2. dart pub get');
  stdout.writeln('  3. dart test');
  stdout.writeln(
    "  4. Add to target project's analysis_options.yaml under 'plugins:'",
  );
}
