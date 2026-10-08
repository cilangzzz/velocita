/// Public surface for the categories feature.
library;

export 'domain/category.dart'
    show
        Category,
        categoryIcon,
        categoryIcons;
export 'domain/classification_rule.dart'
    show
        ClassificationRule,
        RuleFlavor,
        RuleSource;
export 'domain/categories.dart'
    show
        ancestors,
        categoryById,
        categoryIncludesDir,
        childrenOf,
        classifyByRules,
        classifyBySite,
        deepestCategoryForDir,
        dirMatchesAnyCategory,
        openWithSystemHandler,
        resolveSaveDir,
        resolvedSaveDir,
        revealInFolder,
        rootCategories;
export 'data/categories_repository.dart'
    show
        CategoriesNotifier,
        CategoriesState,
        categoriesProvider;
