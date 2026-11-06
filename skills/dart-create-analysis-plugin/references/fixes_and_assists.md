# Quick Fixes & Quick Assists Reference for `analysis_server_plugin`

This reference explains how to implement and test automated code corrections (**Quick Fixes**) and contextual IDE refactorings (**Quick Assists**) using Dart's modern plugin framework.

---

## 1. Quick Fixes vs. Quick Assists

| Feature | Quick Fix | Quick Assist |
| :--- | :--- | :--- |
| **Trigger** | Bound to a specific diagnostic error or lint code | Bound to cursor position or selection in IDE |
| **Registration** | `registry.registerFixForRule(Rule.code, Producer.new)` | `registry.registerAssist(Producer.new)` |
| **Base Class** | `ResolvedCorrectionProducer` | `ResolvedCorrectionProducer` |
| **Constructor** | `Producer({required super.context})` | `Producer({required super.context})` |
| **Kind Getter** | `FixKind get fixKind` | `AssistKind get assistKind` |
| **Purpose** | Fixes code flagged by the analyzer | Refactors code (e.g. wrap with widget, convert method) |

---

## 2. Implementing a Quick Fix

```dart
// lib/src/fixes/add_override_annotation_fix.dart
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddOverrideAnnotationFix extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'my_plugin.add_override',
    DartFixKindPriority.standard, // or integer priority (higher numbers appear higher in IDE menu)
    'Add @override annotation',
  );

  AddOverrideAnnotationFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // 1. Identify target node from diagnostic
    final targetNode = node;

    // 2. Perform file edits
    await builder.addDartFileEdit(file, (fileBuilder) {
      // Insert '@override\n' right before the method declaration
      fileBuilder.addInsertion(targetNode.offset, (editBuilder) {
        editBuilder.writeln('@override');
      });
    });
  }
}
```

---

## 3. Implementing a Quick Assist

Quick Assists do not rely on an error code; they trigger when the user triggers code actions (`Cmd+.` or `Alt+Enter`) at a given cursor offset:

```dart
// lib/src/assists/wrap_with_builder_assist.dart
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class WrapWithBuilderAssist extends ResolvedCorrectionProducer {
  static const _assistKind = AssistKind(
    'my_plugin.wrap_with_builder',
    30,
    'Wrap with CustomBuilder',
  );

  WrapWithBuilderAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _assistKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Check if the current selection is on an InstanceCreationExpression
    final targetNode = node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (targetNode == null) return;

    final nodeText = utils.getNodeText(targetNode);

    await builder.addDartFileEdit(file, (fileBuilder) {
      fileBuilder.addReplacement(range.node(targetNode), (editBuilder) {
        editBuilder.write('CustomBuilder(builder: (context) => ');
        editBuilder.write(nodeText);
        editBuilder.write(')');
      });
    });
  }
}
```

---

## 4. Key `ChangeBuilder` Capabilities

### Adding Imports Automatically
If your replacement code uses a symbol from another library or package, let `fileBuilder` handle import management:
```dart
await builder.addDartFileEdit(file, (fileBuilder) {
  fileBuilder.importLibraryElement(targetLibraryElement);
  // fileBuilder will add the import at the top of the file if not already present
});
```

### Text Edits
```dart
// Replace a node or token
fileBuilder.addReplacement(range.node(node), (editBuilder) {
  editBuilder.write('newCode');
});

// Insert before or after
fileBuilder.addInsertion(node.offset, (editBuilder) {
  editBuilder.writeln('// inserted line');
});

// Delete a node
fileBuilder.addDeletion(range.node(node));
```

### Linking Text Edit Ranges (Interactive Renaming)
For assists or templates where the user should type a variable name:
```dart
editBuilder.addLinkedEdit('VARIABLE_GROUP', (linkedEditBuilder) {
  linkedEditBuilder.write('defaultName');
  linkedEditBuilder.addSuggestion(LinkedEditSuggestionKind.TYPE, 'alternativeName');
});
```

---

## 5. Registering in `lib/main.dart`

```dart
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/my_rule.dart';
import 'src/fixes/add_override_annotation_fix.dart';
import 'src/assists/wrap_with_builder_assist.dart';

final plugin = MyAnalysisPlugin();

class MyAnalysisPlugin extends Plugin {
  @override
  String get name => 'My Analysis Plugin';

  @override
  void register(PluginRegistry registry) {
    // Register Rule
    registry.registerWarningRule(MyRule());

    // Register Fix for Rule
    registry.registerFixForRule(MyRule.code, AddOverrideAnnotationFix.new);

    // Register Assist
    registry.registerAssist(WrapWithBuilderAssist.new);
  }
}
```
