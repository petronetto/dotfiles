# Clean Code

Practices for readable, maintainable code. Applies across languages.

## Naming
- Names reveal intent. Avoid disinformation and abbreviations.
- Use domain terms consistently.

## Functions
- Small and focused: do one thing, at one level of abstraction.
- Few arguments. No flag arguments (split into two functions instead).
- One level of indentation per function. Use guard clauses and early returns; avoid nested conditionals.
- No side effects hidden behind query-style names.

## Structure
- Keep coupling low and cohesion high.
- Define clear module boundaries; program to interfaces, not implementations.
- No magic values — use named constants.
- Separate pure logic from I/O.

## Comments
- Comments explain why, not what. Prefer self-documenting code.
- Delete dead code and commented-out code.
- No noise comments (restating the code).

## Error handling
- Use exceptions or Result types, not return codes or sentinel flags.
- Never swallow errors; fail loudly with context.

## Testing methodology
- Test behavior, not implementation details.
- AAA pattern: Arrange, Act, Assert. One logical assertion per test.
- Mock external dependencies, not your own code.
- Tests must be fast, independent, and repeatable.
- Add tests for every new feature and bug fix.