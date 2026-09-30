/// Public surface for the categories feature.
library;

export 'domain/category.dart' show Category;
export 'domain/classification_rule.dart'
    show
        ClassificationRule,
        RuleFlavor,
        RuleSource;
export 'domain/categories.dart'
    show
        classifyByRules,
        resolveSaveDir,
        openWithSystemHandler,
        revealInFolder;
export 'data/categories_repository.dart'
    show
        CategoriesNotifier,
        CategoriesState,
        categoriesProvider;
