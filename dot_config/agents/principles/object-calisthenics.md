# Object Calisthenics

Nine rules for tighter object-oriented design (from Jeff Bay). Apply strictly where the domain allows; relax for DTOs, adapters, and interop boundaries.

1. **One level of indentation per method.** Extract nested blocks into named methods.
2. **No `else` keyword.** Use guard clauses, early returns, or polymorphism to branch.
3. **Wrap all primitives and strings in value objects.** Encode constraints in the type, not at call sites.
4. **First-class collections.** Wrap collections in classes that encapsulate their behavior.
5. **One dot per line.** Respect the Law of Demeter. Exception: fluent builders and DSLs.
6. **Don't abbreviate.** Clarity over brevity; names carry meaning.
7. **Keep all entities small.** Small classes, methods, files, and packages.
8. **No more than two instance variables per class.** Force collaboration over god-objects.
9. **No getters/setters (properties).** Tell, don't ask; expose behavior, not state. Exception: DTOs and data-transfer boundaries.