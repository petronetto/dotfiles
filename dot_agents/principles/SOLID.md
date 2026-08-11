# SOLID Principles

Five object-oriented design principles. Apply when designing classes and modules; adapt pragmatically in dynamic languages.

## S — Single Responsibility (SRP)
A class should have one reason to change. If a class serves unrelated actors, split it. Cohesion over size.

## O — Open/Closed (OCP)
Open for extension, closed for modification. Add behavior via new code (subclasses, composition, strategies), not by editing tested internals.

## L — Liskov Substitution (LSP)
Subtypes must be substitutable for their base types without altering correct behavior. Never weaken preconditions or strengthen postconditions in a subclass.

## I — Interface Segregation (ISP)
Prefer many small, client-specific interfaces over one general-purpose one. Clients should not depend on methods they do not use.

## D — Dependency Inversion (DIP)
Depend on abstractions, not concretions. Define dependencies as interfaces and inject them; the high-level policy owns the abstraction.