# Widget Convention

**Never write a `StatefulWidget` — use `CompositionWidget` (from
`flutter_compositions`) instead for any widget that holds state, controllers, or
lifecycle (pages, dialogs, sheets, etc.).** `StatelessWidget` is fine for purely
presentational widgets with no state.

- State: `ref()` / `computed()`; side effects: `watch()` / `watchEffect()`.
- Text inputs: `useTextEditingController()` — it owns and auto-disposes the
  controller, so never create or `dispose()` a `TextEditingController` manually
  (doing so right after `showDialog` returns crashes the close animation with
  "A TextEditingController was used after being disposed.").
- Never read `Theme.of(context)`, `MediaQuery.of(context)`, or
  `Localizations.of(context)` directly in the builder — use the
  `useContextRef` / `useTheme` / `useLocale` composables (see below).

# Flutter Compositions Documentation

For comprehensive flutter_compositions reference, see:
- `.claude/llms.txt` — concise guide with core concepts, API patterns, and best practices
- `.claude/llms-full.txt` — complete documentation for in-depth reference

# Flutter Compositions Patterns

## useTextEditingController

This is a powerful utility for handling text input. It not only manages the TextEditingController's lifecycle automatically but also provides two-way binding capabilities.

It returns a record: `(controller, text, value)`

- `controller`: The TextEditingController instance to pass to a TextField.
- `text`: A writable ComputedRef<String> that stays in sync with controller.text.
- `value`: A writable ComputedRef<TextEditingValue> that stays in sync with controller.value.

You can programmatically change the input's content by modifying `text.value`, and you can listen to changes in `text.value` to react to user input.

### Example: Two-Way Binding and Live Validation

```dart
@override
Widget Function(BuildContext) setup() {
  final (usernameController, username, _) = useTextEditingController(text: 'guest');

  // A computed property for the greeting message
  final greeting = computed(() => 'Hello, ${username.value}!');

  // A computed property for simple validation logic
  final isValid = computed(() => username.value.length >= 3);

  return (context) => Column(
    children: [
      Text(greeting.value),
      TextField(
        controller: usernameController,
        decoration: InputDecoration(
          labelText: 'Username',
          errorText: isValid.value ? null : 'Minimum 3 characters required',
        ),
      ),
      ElevatedButton(
        onPressed: () => username.value = 'default', // Programmatically change the text
        child: const Text('Reset'),
      )
    ],
  );
}
```

## Reactive Patterns

### watchEffect for Side Effects

Use `watchEffect` to react to changes in reactive values and notify parent components:

```dart
@override
Widget Function(BuildContext) setup() {
  final props = widget();
  final (controller, text, _) = useTextEditingController(text: props.value.initialValue ?? '');

  // Watch for changes and notify parent
  watchEffect(() {
    props.value.onChanged(text.value);
  });

  return (context) => TextField(controller: controller);
}
```

### computed for Derived State

Use `computed` to create reactive derived values:

```dart
final selectedValue = ref<int?>(null);
final isValid = computed(() => !isRequired || selectedValue.value != null);

// Use in UI - will automatically update when selectedValue changes
errorText: isValid.value ? null : 'This field is required'
```

## InheritedWidget Composables

CompositionWidget's render effect only re-runs when reactive `Ref`s change. Accessing InheritedWidget values directly in the builder (e.g., `Theme.of(context)`, `MediaQuery.of(context)`, `Localizations.localeOf(context)`) does **NOT** trigger re-runs when those values change. You must use the `useContextRef` composable family to bridge InheritedWidget changes into the reactive system.

### useContextRef

Core helper that wraps any context-dependent value into a reactive reference:

```dart
@override
Widget Function(BuildContext) setup() {
  final screenWidth = useContextRef<double>(
    (context) => MediaQuery.of(context).size.width,
  );

  return (context) => Text('Width: ${screenWidth.value}');
}
```

With custom equality (defaults to `identical`):

```dart
final l10n = useContextRef(
  (context) => AppLocalizations.of(context)!,
  equals: (a, b) => a.localeName == b.localeName,
);
```

### Built-in Composables

- **`useLocale()`** — Tracks `Localizations.localeOf(context)`
- **`useTheme()`** — Tracks `Theme.of(context)`
- **`useMediaQuery()`** — Tracks `MediaQuery.of(context)`
- **`useMediaQueryInfo()`** — Returns `(ReadonlyRef<Size>, ReadonlyRef<Orientation>)`
- **`usePlatformBrightness()`** — Tracks `MediaQuery.platformBrightnessOf(context)`
- **`useTextScale()`** — Tracks `MediaQuery.textScalerOf(context)`

### Example: Locale-Aware Widget

```dart
@override
Widget Function(BuildContext) setup() {
  final currentLocale = useLocale();
  final l10n = useContextRef(
    (context) => AppLocalizations.of(context)!,
    equals: (a, b) => a.localeName == b.localeName,
  );

  return (context) => Text(
    '${l10n.value.greeting} (${currentLocale.value.languageCode})',
  );
}
```

### Common Pitfall

```dart
// ❌ WRONG: Reading InheritedWidget directly in builder — won't trigger re-render
return (context) {
  final locale = Localizations.localeOf(context);
  final l10n = AppLocalizations.of(context)!;
  return Text(l10n.hello);
};

// ✅ CORRECT: Using useLocale/useContextRef in setup() — reactive
final locale = useLocale();
final l10n = useContextRef(
  (context) => AppLocalizations.of(context)!,
  equals: (a, b) => a.localeName == b.localeName,
);
return (context) => Text(l10n.value.hello);
```

## Best Practices

1. **Always use reactive refs and computed values** instead of manual state management
2. **Use watchEffect for side effects** like notifying parent components
3. **Destructure properly** when using hooks like `useTextEditingController`
4. **Leverage computed for validation** - it automatically updates the UI when dependencies change
5. **Keep components reactive** - avoid manual setState or callbacks when possible
6. **Use `useContextRef` composables for InheritedWidget values** — never read `Theme.of(context)`, `MediaQuery.of(context)`, `Localizations.localeOf(context)`, or `AppLocalizations.of(context)` directly in the builder function
