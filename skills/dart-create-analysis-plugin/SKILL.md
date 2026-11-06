---
name: dart-create-analysis-plugin
description: Create, test, and integrate custom Dart and Flutter static analysis rules, lints, quick fixes, quick assists, and analyzer plugins using the official modern analysis_server_plugin package (Dart 3.10+ / Flutter 3.38+). Use when asked to create custom lint rules, enforce architectural or API constraints, build an analyzer plugin, provide quick fixes or assists, configure analysis_options.yaml plugins, or troubleshoot plugin execution.
---

# Dart Custom Analysis Rules & Plugins with `analysis_server_plugin`

A comprehensive, production-grade guide for agents and developers to build, test, and activate custom static analysis rules, quick fixes, assists, and plugins using Dart's official modern analyzer plugin architecture (`analysis_server_plugin`), supported natively starting in **Dart 3.10+ (Flutter 3.38+)**.

---

## 1. Official Documentation & Package Resources

Because older LLM training data often references the deprecated legacy `analyzer_plugin` or third-party `custom_lint`, always adhere to the official resources:

- **Pub Package**: [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin)
- **Official Dart SDK Documentation**:
  - [Using Plugins (`using_plugins.md`)](https://raw.githubusercontent.com/dart-lang/sdk/main/pkg/analysis_server_plugin/doc/using_plugins.md)
  - [Writing a Plugin (`writing_a_plugin.md`)](https://raw.githubusercontent.com/dart-lang/sdk/main/pkg/analysis_server_plugin/doc/writing_a_plugin.md)
  - [Writing Rules (`writing_rules.md`)](https://raw.githubusercontent.com/dart-lang/sdk/main/pkg/analysis_server_plugin/doc/writing_rules.md)
  - [Testing Rules (`testing_rules.md`)](https://raw.githubusercontent.com/dart-lang/sdk/main/pkg/analysis_server_plugin/doc/testing_rules.md)
  - [Writing Fixes (`writing_fixes.md`)](https://raw.githubusercontent.com/dart-lang/sdk/main/pkg/analysis_server_plugin/doc/writing_fixes.md)
  - [Writing Assists (`writing_assists.md`)](https://raw.githubusercontent.com/dart-lang/sdk/main/pkg/analysis_server_plugin/doc/writing_assists.md)

### Deep Technical References Included in This Skill
- **AST & Type System**: [references/ast_and_type_hierarchy.md](references/ast_and_type_hierarchy.md) (semantic elements, Flutter Widgets, `BuildContext`, annotations)
- **Fixes & Assists**: [references/fixes_and_assists.md](references/fixes_and_assists.md) (`ChangeBuilder`, text edits, imports, `AssistKind`, `FixKind`)
- **Troubleshooting & Runtime**: [references/troubleshooting_and_faq.md](references/troubleshooting_and_faq.md) (AOT isolates, cache management, VS Code/IntelliJ logs)
- **Scaffolding Utility**: [scripts/scaffold_plugin.dart](scripts/scaffold_plugin.dart) (1-command package generator)

---

## 2. Architecture Overview

1. **Top-Level `plugins` Declaration**: Plugins are registered in `analysis_options.yaml` under the top-level `plugins:` key (never nested under `analyzer:`).
2. **Synthetic Package Execution**: When the Dart Analysis Server starts, it generates a synthetic package under `~/.dartServer/.plugin_manager/<hash>`, adds the plugin dependencies, runs `dart pub upgrade`, and compiles an AOT snapshot (`plugin.aot`) running in an isolated background isolate.
3. **Dual Coverage**: Once activated, rules automatically report in:
   - **Interactive IDEs** (VS Code, IntelliJ IDEA, Android Studio) with inline squigglies, Problems tab entries, and quick fixes.
   - **CLI Analysis** (`dart analyze`, `flutter analyze`) for continuous integration (CI).

---

## 3. Scaffolding the Plugin Package

Always isolate the plugin in its own package (e.g. `packages/my_analyzer_plugin` or `tools/my_lints`):

### Option A: 1-Command CLI Scaffolding (Recommended)
Run the bundled Dart script (resolve `<skill_dir>` to the directory containing this `SKILL.md` file):
```bash
dart <skill_dir>/scripts/scaffold_plugin.dart --name my_analyzer_plugin --rule avoid_empty_catch
```

### Option B: Manual Setup
Create a new package and add the required dependencies via `dart pub add` so Pub resolves versions compatible with your active Dart SDK (verified for Dart 3.10+ / Flutter 3.38+):
```bash
dart pub add analysis_server_plugin analyzer analyzer_plugin
dart pub add --dev analyzer_testing test test_reflective_loader lints
```

Or configure `pubspec.yaml` directly:
```yaml
# pubspec.yaml
name: my_analyzer_plugin
description: Custom static analysis rules, fixes, and assists.
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
```

> [!NOTE]
> Isolating the plugin in its own package prevents `analyzer` package constraints from conflicting with production application dependencies (e.g., code generators like `build_runner` or `freezed`).

---

## 4. Full Plugin Entrypoint & Capabilities

The plugin entrypoint MUST be located at `lib/main.dart` and expose a top-level `plugin` variable.

```dart
// lib/main.dart
import 'dart:async';
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/my_rule.dart';
import 'src/fixes/my_fix.dart';
import 'src/assists/my_assist.dart';

final plugin = MyPlugin();

class MyPlugin extends Plugin {
  @override
  String get name => 'My Plugin';

  @override
  FutureOr<void> register(PluginRegistry registry) {
    // 1. Warning Rules: Enabled by default when the plugin is listed
    registry.registerWarningRule(MyRule());

    // 2. Lint Rules: Disabled by default; must be explicitly enabled in analysis_options.yaml
    registry.registerLintRule(MyOptionalLintRule());

    // 3. Quick Fixes: Associates a code correction with a specific diagnostic code
    registry.registerFixForRule(MyRule.code, MyFixProducer.new);

    // 4. Quick Assists: Contextual IDE refactorings/code actions
    registry.registerAssist(MyAssistProducer.new);
  }

  @override
  FutureOr<void> start() {
    // Optional startup initialization per analysis context
  }

  @override
  FutureOr<void> shutDown() {
    // Optional cleanup on plugin termination
  }
}
```

---

## 5. Implementing Analysis Rules

Rules inspect AST nodes and report diagnostics.

### Single-Code Rule (`AnalysisRule`)
```dart
// lib/src/rules/my_rule.dart
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class MyRule extends AnalysisRule {
  // CRITICAL: Instantiate LintCode as a `static const` field.
  // The server relies on instance identity to match diagnostics for // ignore: comments.
  static const LintCode code = LintCode(
    'my_rule',
    'Problem description highlighting {0}.',
    correctionMessage: 'Try correcting the issue this way.',
    uniqueName: 'LintCode.my_rule',
    // Optional: defaults to DiagnosticSeverity.INFO; can be set to .WARNING or .ERROR
  );

  MyRule()
      : super(
          name: 'my_rule',
          description: 'A concise summary of what this rule enforces.',
        );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    // Register the AST nodes to visit (e.g. addMethodDeclaration, addClassDeclaration, etc.)
    registry.addMethodDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // 1. Filter out irrelevant elements (e.g., static, private, operators)
    if (node.isStatic || node.name.lexeme.startsWith('_')) {
      return;
    }

    // 2. Robust AST hierarchy navigation:
    // Avoid fragile `node.parent as ClassDeclaration` casts because intermediate AST nodes
    // (such as BlockClassBody) may sit between a member and its enclosing ClassDeclaration.
    // Always use `thisOrAncestorOfType`:
    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) {
      return;
    }

    // 3. Inspect semantic elements and types
    final element = node.declaredFragment?.element;
    if (element == null) {
      return;
    }

    // 4. Report violation at the target token or node
    final isViolation = /* check custom condition */;
    if (isViolation) {
      rule.reportAtToken(node.name, arguments: [node.name.lexeme]);
    }
  }
}
```

### Multi-Code Rule (`MultiAnalysisRule`)
When a rule can report multiple distinct diagnostic codes:
```dart
class MyMultiRule extends MultiAnalysisRule {
  static const codeA = LintCode('my_rule_a', 'Issue A message');
  static const codeB = LintCode('my_rule_b', 'Issue B message');

  MyMultiRule() : super(name: 'my_multi_rule', description: '...');

  @override
  List<DiagnosticCode> get diagnosticCodes => [codeA, codeB];

  // In visitor: rule.reportAtToken(node.name, diagnosticCode: codeA);
}
```

---

## 6. Implementing Quick Fixes & Quick Assists

Both Quick Fixes and Quick Assists subclass `ResolvedCorrectionProducer`, accept `{required super.context}`, and declare their `CorrectionApplicability`.

### Quick Fix (`ResolvedCorrectionProducer` with `FixKind`)
Bound to a specific diagnostic code via `registry.registerFixForRule(MyRule.code, MyFixProducer.new)`:
```dart
// lib/src/fixes/my_fix.dart
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class MyFixProducer extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'my_plugin.fix',
    DartFixKindPriority.standard, // or integer priority like 50
    'Apply automatic fix',
  );

  MyFixProducer({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    await builder.addDartFileEdit(file, (fileBuilder) {
      fileBuilder.addReplacement(range.node(node), (editBuilder) {
        editBuilder.write('replacementCode()');
      });
    });
  }
}
```

### Quick Assist (`ResolvedCorrectionProducer` with `AssistKind`)
Contextual IDE code action available at the user's cursor via `registry.registerAssist(MyAssistProducer.new)`:
```dart
// lib/src/assists/my_assist.dart
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class MyAssistProducer extends ResolvedCorrectionProducer {
  static const _assistKind = AssistKind(
    'my_plugin.assist',
    30,
    'Wrap with custom handler',
  );

  MyAssistProducer({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final targetNode = node;
    final nodeText = utils.getNodeText(targetNode);

    await builder.addDartFileEdit(file, (fileBuilder) {
      fileBuilder.addReplacement(range.node(targetNode), (editBuilder) {
        editBuilder.write('wrap($nodeText)');
      });
    });
  }
}
```

---

## 7. Automated Unit Testing with `analyzer_testing`

Use `package:analyzer_testing` to write isolated, deterministic unit tests without launching the full analysis server:

```dart
// test/my_rule_test.dart
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:my_analyzer_plugin/src/rules/my_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MyRuleTest);
  });
}

@reflectiveTest
class MyRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MyRule();

    // Stub external package dependencies or base types
    newPackage('my_core').addFile('lib/my_core.dart', r'''
abstract class BaseType {}
''');

    super.setUp();
  }

  Future<void> test_validCode() async {
    await assertNoDiagnostics(r'''
import 'package:my_core/my_core.dart';

class ValidClass extends BaseType {
  void validMethod() {}
}
''');
  }

  Future<void> test_invalidCode() async {
    await assertDiagnostics(
      r'''
import 'package:my_core/my_core.dart';

class InvalidClass extends BaseType {
  void badMethod() {}
}
''',
      [
        lint(85, 9), // offset (85) and character length (9) of 'badMethod'
      ],
    );
  }
}
```

Run test suite:
```bash
dart test
```

---

## 8. Activating and Configuring in Projects

In the root `analysis_options.yaml` of the target project or workspace:

### 1. By Local Path (Monorepo / Local Development)
```yaml
plugins:
  my_analyzer_plugin:
    path: ../my_analyzer_plugin
```

### 2. By Pub.dev Version Constraint
```yaml
plugins:
  my_analyzer_plugin: ^1.0.0
```

### 3. By Git Repository
```yaml
plugins:
  my_analyzer_plugin:
    git:
      url: https://github.com/my-org/my-plugin.git
      ref: main
      path: packages/plugin_dir
```

### 4. Configuring Specific Diagnostics
```yaml
plugins:
  my_analyzer_plugin:
    path: ../my_analyzer_plugin
    diagnostics:
      my_rule: true               # Explicitly enable lint rule
      noisy_warning_rule: false   # Disable default warning rule
```

### 5. In-Code Diagnostic Suppression
Diagnostics generated by modern plugins use the `<plugin_name>/<diagnostic_name>` format:
```dart
// ignore: my_analyzer_plugin/my_rule
void someFlaggedMethod() {}

// ignore_for_file: my_analyzer_plugin/my_rule
```

---

## 9. Verification & Cache Maintenance

1. **Verify CLI**: Run `dart analyze` or `flutter analyze` from the project root.
2. **Reload IDE**:
   - **IntelliJ / Android Studio**: Click **Restart Dart Analysis Server** (the circular refresh icon in the Dart Analysis window).
   - **VS Code**: Run `Dart: Restart Analysis Server` from the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`).
3. **Clear Plugin Cache**:
   If code edits inside the plugin package fail to reflect in the analysis server:
   ```bash
   rm -rf ~/.dartServer/.plugin_manager
   ```
   Restarting the analysis server will rebuild the synthetic package and recompile `plugin.aot`.
