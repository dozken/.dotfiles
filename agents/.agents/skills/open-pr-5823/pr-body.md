## Problem

Python editor autocomplete lost `$datasource`/schema/table suggestions, `synergy.executors|datasources|llm.*` argument completions, and Jedi backend completions. Only `synergy.variables.*` remained.

## Mechanism

The pipeline Python step and the case Code-Editor Python mode inject a variables-only `PythonAutocomplete` as `autocompleteProvider`. `base-editor-store` wired injected providers via `autoCompleteProvider ?? this.autoCompleteProvider`, so an injected provider **replaced** the built-in DM-aware provider instead of layering on it — dropping every non-variable completion.

## Fix

- New opt-in `CompositeAutocompleteProvider`: runs primary (injected) → falls through to the fallback (built-in) when the primary yields nothing. Trigger characters are unioned; the primary variable-context is preferred.
- `base-editor-store` gains a `composeInjectedProvider` flag; `PythonEditorStore` sets it `true`, so the injected variables provider now **layers on** the built-in DM/Jedi provider.
- The variables-only provider's default branch returns `[]` so the composite falls through to Jedi.
- SQL surfaces are untouched (the opt-in flag is off there).

## Demo

https://github.com/user-attachments/assets/ce465b09-bdd9-4870-8bc8-e8969e9b7812

Closes #5823
