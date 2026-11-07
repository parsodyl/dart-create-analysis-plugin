# dart-create-analysis-plugin

An expert **AI Agent Skill** for creating, testing, and integrating custom Dart & Flutter static analysis rules, lints, quick fixes, quick assists, and analyzer plugins using Dart's official modern **`analysis_server_plugin`** architecture (**Dart 3.10+ / Flutter 3.38+**).

---

## ✨ What You Can Do With This Skill

Most AI models were trained on deprecated `analyzer_plugin` (JSON-RPC) or third-party `custom_lint` patterns. When this skill is installed in your coding agent, your assistant knows how to:

1. **Scaffold a Complete Plugin Package in 1 Command**
   - Bootstrap a standalone analyzer plugin package with the bundled `scaffold_plugin.dart` CLI script (`pubspec.yaml`, `lib/main.dart`, rules, fixes, assists, and unit tests).
2. **Write Custom Static Analysis & Architecture Rules (`AnalysisRule` & `MultiAnalysisRule`)**
   - Enforce architectural boundaries (e.g., banning direct `Navigator` or `HttpClient` calls in UI widgets, enforcing state management conventions, or validating annotations).
   - Navigate Dart 3.10+ AST hierarchies safely (`BlockClassBody`, `thisOrAncestorOfType<T>()`, `declaredFragment?.element`, `TypeSystem`, and `InterfaceElement.allSupertypes`).
3. **Build Automated IDE Quick Fixes & Quick Assists (`ResolvedCorrectionProducer`)**
   - Attach one-click code fixes (`FixKind`) to custom lint diagnostics using `ChangeBuilder`.
   - Create contextual IDE refactorings (`AssistKind`) available at the developer's cursor (`Cmd+.` / `Alt+Enter`), such as wrapping widgets or statements.
4. **Write Fast, Deterministic Unit Tests (`analyzer_testing`)**
   - Test rules and diagnostics in memory using `AnalysisRuleTest`, `assertDiagnostics`, `assertNoDiagnostics`, and mocked external packages (`newPackage(...)`).
5. **Configure & Troubleshoot `analysis_options.yaml`**
   - Wire plugins via local paths (monorepos), Git repositories, or `pub.dev` constraints under the top-level `plugins:` key.
   - Diagnose AOT plugin compilation, inspect the Analyzer Diagnostics UI, and manage `~/.dartServer/.plugin_manager` snapshots.

---

## 📦 Installation Options

Because `SKILL.md` is housed cleanly inside [`skills/dart-create-analysis-plugin/`](skills/dart-create-analysis-plugin/), skill installers only copy the skill payload into your agent configuration without polluting it with repository metadata.

### 1. Vercel Skills CLI (`npx skills`)
Supports **Antigravity**, **Claude Code**, **Codex**, **Cursor**, **GitHub Copilot**, **Cline**, and many others:

```bash
# Install into your current project workspace
npx skills add parsodyl/dart-create-analysis-plugin

# Or install globally across all projects
npx skills add parsodyl/dart-create-analysis-plugin -g
```

### 2. Dart Skills CLI (`package:skills`)
Using the official Dart ecosystem `skills` runner:

```bash
# Run transiently via Dart 3.10+ (project or global):
dart run skills@ add https://github.com/parsodyl/dart-create-analysis-plugin.git
dart run skills@ add https://github.com/parsodyl/dart-create-analysis-plugin.git --global

# Or activate globally via Dart pub:
dart pub global activate skills
skills add https://github.com/parsodyl/dart-create-analysis-plugin.git
```

### 3. Manual / Git Clone Installation
Clone this repository and copy (or symlink) the `skills/dart-create-analysis-plugin` folder directly into your AI assistant's **project skills path** (locally in your workspace) or **global skills path**.

For example, with **Antigravity** or **Claude Code**:

```bash
git clone https://github.com/parsodyl/dart-create-analysis-plugin.git

# Antigravity (project-level or global)
cp -R dart-create-analysis-plugin/skills/dart-create-analysis-plugin .agents/skills/
cp -R dart-create-analysis-plugin/skills/dart-create-analysis-plugin ~/.gemini/config/skills/

# Claude Code (project-level or global)
cp -R dart-create-analysis-plugin/skills/dart-create-analysis-plugin .claude/skills/
cp -R dart-create-analysis-plugin/skills/dart-create-analysis-plugin ~/.claude/skills/
```

---

## 🗂️ Skill Layout

```text
dart-create-analysis-plugin/
├── SKILL.md                                 # Core instructions & API templates
├── scripts/
│   └── scaffold_plugin.dart                 # 1-command Dart CLI plugin generator
├── references/
│   ├── ast_and_type_hierarchy.md            # Deep AST traversal & Flutter type checks
│   ├── fixes_and_assists.md                 # Quick Fixes, Quick Assists & ChangeBuilder
│   └── troubleshooting_and_faq.md           # AOT isolate runtime, debugging & cache management
└── evals/
    └── evals.json                           # Evaluation prompts & assertions
```

---

## 💬 Example Prompts to Try After Installing

- *"Create a custom analyzer plugin in `tools/app_lints` that warns whenever a `StatelessWidget` or `StatefulWidget` directly invokes `Navigator.of(context).push`, and write unit tests for it."*
- *"Add a custom lint rule and quick fix that flags empty `catch (e) {}` blocks and offers a quick fix to insert a `rethrow;` or error logging call."*
- *"Write a quick assist in our analyzer plugin that lets developers wrap any widget expression in a `CustomBuilder`."*

---

## 📄 License

[MIT License](LICENSE).
