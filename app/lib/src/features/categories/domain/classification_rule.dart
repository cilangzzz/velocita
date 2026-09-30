/// A single classification rule — points a filename pattern at a category.
///
/// Three flavors:
///   - `extension` (e.g. `.iso`) — exact extension match
///   - `substring` (e.g. `linux-mint`) — case-insensitive contains
///   - `regex`    (e.g. `^ubuntu-\d+\.\d+`) — Dart RegExp
///
/// Higher priority rules win on conflict. Priorities are user-assigned
/// integers; the default seed rules get priority 0–99.
class ClassificationRule {
  ClassificationRule({
    required this.id,
    required this.categoryId,
    required this.pattern,
    required this.flavor,
    required this.priority,
    required this.source,
  });

  final String id;
  final String categoryId;
  final String pattern;
  final RuleFlavor flavor;
  final int priority;
  final RuleSource source;

  /// Pure Dart regex pre-compiled once; cached so `matches()` is fast.
  RegExp? _regex;
  RegExp? _compiled() {
    if (flavor != RuleFlavor.regex) return null;
    return _regex ??= RegExp(pattern, caseSensitive: false);
  }

  bool matches(String filename) {
    final f = filename.toLowerCase();
    switch (flavor) {
      case RuleFlavor.extension:
        return f.endsWith(pattern.toLowerCase());
      case RuleFlavor.substring:
        return f.contains(pattern.toLowerCase());
      case RuleFlavor.regex:
        return _compiled()?.hasMatch(filename) ?? false;
    }
  }

  ClassificationRule copyWith({
    String? pattern,
    RuleFlavor? flavor,
    int? priority,
  }) {
    return ClassificationRule(
      id: id,
      categoryId: categoryId,
      pattern: pattern ?? this.pattern,
      flavor: flavor ?? this.flavor,
      priority: priority ?? this.priority,
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'pattern': pattern,
        'flavor': flavor.name,
        'priority': priority,
        'source': source.name,
      };

  factory ClassificationRule.fromJson(Map<String, dynamic> json) {
    return ClassificationRule(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      pattern: json['pattern'] as String,
      flavor: RuleFlavor.values.byName(json['flavor'] as String),
      priority: json['priority'] as int,
      source: RuleSource.values.byName(json['source'] as String),
    );
  }
}

enum RuleFlavor { extension, substring, regex }

/// Where the rule came from. Used for diagnostics and the "Reset to
/// defaults" UI action.
enum RuleSource { defaultSeed, userDefined, script }
