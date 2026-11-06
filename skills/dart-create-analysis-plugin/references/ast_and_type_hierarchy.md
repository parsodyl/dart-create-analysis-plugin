# AST Traversal & Type System Reference for `analysis_server_plugin`

This reference covers deep AST inspection, semantic element resolution, and type hierarchy checks in Dart 3.10+ using `package:analyzer`.

---

## 1. AST Node Visitors

The recommended pattern is to extend `SimpleAstVisitor<void>` and register callbacks in `AnalysisRule.registerNodeProcessors`:

```dart
@override
void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
  final visitor = _RuleVisitor(this, context);
  // Register specific AST node types to avoid traversing the entire tree:
  registry.addClassDeclaration(this, visitor);
  registry.addMethodDeclaration(this, visitor);
  registry.addInstanceCreationExpression(this, visitor);
  registry.addMethodInvocation(this, visitor);
}
```

### Common AST Node Types
| AST Node | What It Represents | Useful Properties |
| :--- | :--- | :--- |
| `ClassDeclaration` | `class Foo<T> extends Bar {}` | `name`, `members`, `extendsClause`, `withClause`, `implementsClause` |
| `MethodDeclaration` | Instance or static method | `name`, `parameters`, `returnType`, `body`, `isStatic`, `isGetter` |
| `ConstructorDeclaration` | Class constructor | `name`, `initializers`, `parameters`, `factoryKeyword` |
| `FieldDeclaration` | Variable inside a class | `fields.variables`, `isStatic`, `fields.type` |
| `InstanceCreationExpression` | `Widget(...)` or `new Widget()` | `constructorName`, `argumentList`, `staticType` |
| `MethodInvocation` | `object.method(args)` | `methodName`, `target`, `argumentList`, `staticInvokeType` |
| `FunctionExpression` | Anonymous closure or arrow function | `parameters`, `body` |
| `ReturnStatement` | `return expression;` | `expression` |
| `ThrowExpression` | `throw Exception();` | `expression` |

---

## 2. Navigating the AST Hierarchy Safely

Avoid relying on direct `node.parent as ClassDeclaration` casts, as intermediate AST nodes (such as `BlockClassBody`) may sit between a `ClassDeclaration` and its members. Always use `thisOrAncestorOfType<T>()` to traverse upward safely.

### Safe Navigation Helper: `thisOrAncestorOfType<T>()`
```dart
// Locate enclosing class
final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();

// Locate enclosing method or function
final enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
final enclosingFunction = node.thisOrAncestorOfType<FunctionBody>();
```

### Checking Enclosing Member Kind
```dart
bool isInsideAsyncFunction(AstNode node) {
  final body = node.thisOrAncestorOfType<FunctionBody>();
  return body != null && body.isAsynchronous;
}
```

---

## 3. Semantic Element & Type Resolution

An AST node represents syntax; its **Element** represents semantics (types, library origins, symbols).

### Getting Elements in Modern Analyzer
```dart
// On declarations:
final methodElement = node.declaredFragment?.element; // MethodElement
final classElement = classNode.declaredFragment?.element; // ClassElement

// On references or expressions:
final calledElement = invocation.methodName.element; // ExecutableElement?
final expressionType = expression.staticType; // DartType?
```

---

## 4. Checking Inheritance & Subtypes (Flutter Widgets, Models)

To test if a class extends a specific type (e.g. Flutter `StatelessWidget`, `StatefulWidget`, `ChangeNotifier`):

### Checking Supertypes via `InterfaceElement.allSupertypes`
```dart
class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final classElement = node.declaredFragment?.element;
    if (classElement == null) return;

    // 1. Check direct or transitive superclass / interface:
    if (_isSubtypeOf(classElement, 'Widget', 'package:flutter/src/widgets/framework.dart')) {
      // Logic for Flutter Widgets
    }
  }

  bool _isSubtypeOf(InterfaceElement element, String targetName, String targetUri) {
    // Check all supertypes transitively (extends, with, implements)
    for (final superType in element.allSupertypes) {
      final superElement = superType.element;
      if (superElement.name == targetName &&
          superElement.library.identifier == targetUri) {
        return true;
      }
    }
    return false;
  }
}
```

### Checking Expression `DartType`
```dart
void visitMethodInvocation(MethodInvocation node) {
  final target = node.target;
  if (target == null) return;

  final type = target.staticType;
  if (type == null) return;

  // Check if target is a BuildContext
  if (type.element?.name == 'BuildContext' &&
      type.element?.library.identifier.startsWith('package:flutter/') == true) {
    // Flag prohibited operations on BuildContext
  }
}
```

### Checking Primitive & Core Types via `TypeProvider`
`context.typeProvider` gives immediate access to core Dart types without string comparisons:
```dart
final typeProvider = context.typeProvider;

if (expression.staticType == typeProvider.stringType) { ... }
if (expression.staticType == typeProvider.boolType) { ... }
if (context.typeSystem.isSubtypeOf(expression.staticType!, typeProvider.futureType(typeProvider.voidType))) {
  // Matches Future<void>
}
```

---

## 5. Checking Annotations

To inspect whether a class, field, or method is annotated with `@immutable`, `@override`, or a custom annotation, prefer checking the semantic `elementAnnotation` (which handles import prefixes like `@meta.immutable` and constructor annotations) with a syntactic fallback:

```dart
bool hasAnnotation(AnnotatedNode node, String annotationName) {
  for (final annotation in node.metadata) {
    final element = annotation.elementAnnotation?.element;
    if (element?.name == annotationName ||
        element?.enclosingElement?.name == annotationName ||
        annotation.name.name == annotationName) {
      return true;
    }
  }
  return false;
}

// Or using built-in ElementAnnotation helpers on the semantic element:
final classElement = classDeclaration.declaredFragment?.element;
final isImmutable = classElement?.metadata.hasImmutable ?? false;

// Example usage:
if (!hasAnnotation(classDeclaration, 'immutable')) {
  rule.reportAtToken(classDeclaration.name);
}
```

---

## 6. Reporting Violations Accurately

Always report diagnostics on the most specific token possible to give users accurate IDE highlights:

```dart
// Best: underlines just the identifier name
rule.reportAtToken(node.name);

// Good: underlines the entire declaration or statement
rule.reportAtNode(node);

// With message parameters for format strings '{0}':
// LintCode('my_rule', 'Class {0} must extend BaseState.')
rule.reportAtToken(node.name, arguments: [node.name.lexeme]);
```
