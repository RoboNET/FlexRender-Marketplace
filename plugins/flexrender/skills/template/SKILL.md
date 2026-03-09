---
name: template
description: "Use when creating, editing, debugging, or rendering FlexRender YAML templates. Covers full YAML syntax, all 11 element types, flexbox layout, template expressions, CLI commands, and live preview via watch mode."
---

# FlexRender Template Authoring

## Overview

Help users create, edit, debug, and render FlexRender YAML templates. FlexRender is a .NET library for rendering images from YAML templates with CSS-like flexbox layout.

## Workflow

### Modes

Determine the mode based on context:

- **Create** — template file doesn't exist. Ask about purpose (receipt, label, card, ticket), canvas dimensions, required elements. Generate YAML, offer to start `flexrender watch`.
- **Edit** — template file exists. Read it first, understand structure, apply changes.
- **Debug** — template has errors or layout issues. Use `flexrender validate` for syntax errors, `flexrender debug-layout` for layout visualization.

### Watch Mode (Live Preview)

At the start of any template work, offer to run watch mode for live preview:

```bash
flexrender watch template.yaml -d data.json -o preview.png
```

This runs in the background and re-renders on every file save. Always suggest this for iterative work.

After significant changes, if watch is not running, offer to render a preview:

```bash
flexrender render template.yaml -d data.json -o preview.png
```

### Validation

After creating or editing a template, always validate:

```bash
flexrender validate template.yaml
```

If validation fails, analyze the error and fix the template.

## Template Structure

```yaml
template:                     # Required: metadata
  name: "my-template"         # Template name (string)
  version: 1                  # Template version (int)
  culture: "ru-RU"            # Culture for number/date formatting (optional)

fonts:                        # Optional: font definitions
  - "assets/fonts/Inter-Regular.ttf"       # First unnamed = "default"/"main"
  - "assets/fonts/Inter-Bold.ttf"
  - path: "assets/fonts/Roboto-Regular.ttf"
    name: heading
    fallback: "Arial"

canvas:                       # Required: canvas settings
  fixed: width                # Fixed dimension: width, height, both, none
  width: 300                  # Canvas width in pixels
  height: 0                   # Canvas height (0 = auto)
  background: "#ffffff"       # Background color
  text-direction: ltr         # Text direction: ltr, rtl
  rotate: none                # Post-render rotation: none, left, right, flip, <degrees>

layout:                       # Required: array of elements
  - type: text
    content: "Hello!"
```

### Canvas Fixed Dimension

| Value | Behavior |
|-------|----------|
| `width` | Width fixed, height auto (default) |
| `height` | Height fixed, width auto |
| `both` | Both dimensions fixed |
| `none` | Both dimensions auto |

### Font Registration

**List format (recommended):**
```yaml
fonts:
  - "assets/fonts/Inter-Regular.ttf"      # First unnamed = "default"/"main"
  - "assets/fonts/Inter-Bold.ttf"
  - path: "assets/fonts/Noto-Regular.ttf"
    name: arabic
    fallback: "Arial"
```

**Dictionary format (legacy):**
```yaml
fonts:
  default: "assets/fonts/Inter-Regular.ttf"
  bold: "assets/fonts/Inter-Bold.ttf"
```

Font sources: local file paths, `embedded://` resources, `http://` URLs. Supported: `.ttf`, `.otf`.

Automatic sibling discovery: register only the regular font — `fontWeight: bold` automatically finds `Inter-Bold.ttf` in the same directory.

## Units

| Unit | Syntax | Example |
|------|--------|---------|
| px | `"100"`, `"100px"` | `width: "100"` |
| % | `"50%"` | `width: "50%"` |
| em | `"1.5em"` | `size: "1.5em"` |
| auto | `"auto"`, `null` | `width: "auto"` |

Plain numbers = pixels. CSS shorthand for padding/margin:
- `"20"` — all sides
- `"20 40"` — vertical horizontal
- `"20 40 30"` — top horizontal bottom
- `"20 40 30 10"` — top right bottom left

## Colors

Hex format: `#rrggbb` or `#rgb` shorthand. Examples: `"#ff0000"`, `"#f00"`.

Gradients on `background`:
```yaml
background: "linear-gradient(180deg, #ff0000, #0000ff)"
```

## Element Types

### text

```yaml
- type: text
  content: "Hello, {{name}}!"
  font: main
  fontFamily: "Arial"
  fontWeight: bold          # thin(100), extra-light(200), light(300), normal(400), medium(500), semi-bold(600), bold(700), extra-bold(800), black(900)
  fontStyle: normal         # normal, italic, oblique
  size: 1.2em
  color: "#000000"
  align: left               # left, center, right, start, end
  wrap: true
  overflow: ellipsis        # ellipsis, clip, visible
  maxLines: 2
  lineHeight: "1.5"         # multiplier, "24px", "2em", "" (default)
```

### flex

```yaml
- type: flex
  direction: column         # column, row, column-reverse, row-reverse
  wrap: nowrap              # nowrap, wrap, wrap-reverse
  gap: "10"                 # Shorthand for both rowGap and columnGap
  columnGap: "10"
  rowGap: "10"
  justify: start            # start, center, end, space-between, space-around, space-evenly
  align: stretch            # start, center, end, stretch, baseline
  alignContent: start       # start, center, end, stretch, space-between, space-around, space-evenly
  overflow: visible         # visible, hidden
  children:
    - type: text
      content: "child"
```

### image

```yaml
- type: image
  src: "logo.png"           # File path, http://, embedded://, data:image/png;base64,...
  width: "100"
  height: "50"
  fit: contain              # fill, contain, cover, none
```

Only relative paths allowed (security). Image fit modes:
- `fill` — stretch to bounds (may distort)
- `contain` — fit within bounds (may have empty space)
- `cover` — cover bounds (may crop)
- `none` — natural size

### qr

Requires `FlexRender.QrCode` package / `.WithQr()`.

```yaml
- type: qr
  data: "{{paymentUrl}}"
  size: 120
  errorCorrection: M        # L(7%), M(15%), Q(25%), H(30%)
  foreground: "#000000"
```

### barcode

Requires `FlexRender.Barcode` package / `.WithBarcode()`.

```yaml
- type: barcode
  data: "{{sku}}"
  format: code128            # code128, code39, ean13, ean8, upc
  width: 200
  height: 80
  showText: true
  foreground: "#000000"
```

### separator

```yaml
- type: separator
  orientation: horizontal    # horizontal, vertical
  style: dotted              # dotted, dashed, solid
  thickness: 1
  color: "#000000"
```

### table

```yaml
- type: table
  array: items               # Data array path (dynamic rows)
  as: item                   # Variable name
  columns:
    - key: name
      label: "Product"
      grow: 1
      align: left            # left, center, right
    - key: price
      label: "Price"
      width: "80"
      align: right
  rows:                      # Static rows (alternative to array)
    - values:
        name: "Total"
        price: "{{total}}"
      font: bold
  headerFont: bold
  headerFontWeight: bold
  headerFontStyle: normal
  headerFontFamily: null
  headerColor: "#000000"
  headerSize: null
  headerBackground: "#f0f0f0"
```

### svg

Requires `FlexRender.SvgElement` package / `.WithSvgElement()`.

```yaml
# From file
- type: svg
  src: "assets/icons/logo.svg"
  width: 120
  height: 40
  fit: contain               # fill, contain, cover, none

# Inline
- type: svg
  content: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#4CAF50"/></svg>'
  width: 48
  height: 48
```

Must specify exactly one of `src` or `content`.

### content

Embeds formatted text (Markdown, HTML, NDC) using content parsers.

```yaml
- type: content
  source: "{{body}}"
  format: markdown           # markdown, html, ndc
  options: {}                # Parser-specific options (used by NDC)
```

### each (loop)

```yaml
- type: each
  array: items               # Path to array in data (required)
  as: item                   # Variable name (optional)
  children:
    - type: text
      content: "{{@index}}. {{item.name}}: {{item.price}}"
```

Loop variables: `{{@index}}` (0-based), `{{@first}}`, `{{@last}}`, `{{@key}}` (for object iteration).

### if (conditional)

```yaml
- type: if
  condition: isPremium
  then:
    - type: text
      content: "Premium"
  elseIf:
    condition: status
    equals: "pending"
    then:
      - type: text
        content: "Pending"
  else:
    - type: text
      content: "Standard"
```

13 operators:

| Operator | YAML Key | Example |
|----------|----------|---------|
| Truthy | _(none)_ | `condition: discount` |
| Equals | `equals` | `equals: "paid"` |
| NotEquals | `notEquals` | `notEquals: "cancelled"` |
| In | `in` | `in: ["admin", "mod"]` |
| NotIn | `notIn` | `notIn: ["banned"]` |
| Contains | `contains` | `contains: "urgent"` |
| GreaterThan | `greaterThan` | `greaterThan: 1000` |
| GreaterThanOrEqual | `greaterThanOrEqual` | `greaterThanOrEqual: 10` |
| LessThan | `lessThan` | `lessThan: 5` |
| LessThanOrEqual | `lessThanOrEqual` | `lessThanOrEqual: 2` |
| HasItems | `hasItems` | `hasItems: true` |
| CountEquals | `countEquals` | `countEquals: 1` |
| CountGreaterThan | `countGreaterThan` | `countGreaterThan: 5` |

## Common Properties (All Elements)

All elements inherit these:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `padding` | string | `"0"` | Inner spacing (CSS shorthand) |
| `margin` | string | `"0"` | Outer spacing (CSS shorthand, supports `auto`) |
| `background` | string? | null | Background color or gradient |
| `opacity` | float | 1.0 | Opacity 0.0-1.0 |
| `box-shadow` | string? | null | `"offsetX offsetY blur color"` |
| `rotate` | string | `"none"` | none/left/right/flip/degrees |
| `display` | Display | flex | flex, none |
| `grow` | float | 0 | Flex grow factor |
| `shrink` | float | 1 | Flex shrink factor |
| `basis` | string | `"auto"` | Flex basis |
| `alignSelf` | AlignSelf | auto | auto, start, center, end, stretch, baseline |
| `order` | int | 0 | Display order |
| `width` | string? | null | px, %, em, auto |
| `height` | string? | null | px, %, em, auto |
| `minWidth` | string? | null | Minimum width |
| `maxWidth` | string? | null | Maximum width |
| `minHeight` | string? | null | Minimum height |
| `maxHeight` | string? | null | Maximum height |
| `position` | Position | static | static, relative, absolute |
| `top` | string? | null | Top inset (positioned) |
| `right` | string? | null | Right inset (positioned) |
| `bottom` | string? | null | Bottom inset (positioned) |
| `left` | string? | null | Left inset (positioned) |
| `aspectRatio` | float? | null | Width/height ratio |
| `text-direction` | TextDirection? | null | ltr, rtl (inherit from parent) |

## Template Expressions

Expressions are processed in three phases:
1. **AST-level** (`TemplateExpander`) — expands `type: each` and `type: if` into concrete elements
2. **Inline** (`TemplatePipeline`) — resolves `{{variable}}` in all property values
3. **Materialization** — resolved strings parsed into typed values (float, int, bool, enum)

### Variable Substitution

```yaml
# Simple variable
content: "Hello, {{name}}!"

# Dot notation for nested access
content: "City: {{user.address.city}}"

# Array index access
content: "First: {{items[0].name}}"

# Combined path and index
content: "{{orders[0].items[2].name}}"

# Computed key access (dynamic key from variable)
content: "{{translations[lang]}}"

# String literal key
content: '{{translations["en"]}}'

# Chained access
content: "{{sections[current].title}}"

# Nested computed access
content: "{{dict[keys[0]]}}"

# Expression as key
content: "Item: {{arr[base + offset]}}"
```

### Arithmetic

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `{{price + tax}}` |
| `-` | Subtraction | `{{total - discount}}` |
| `*` | Multiplication | `{{price * quantity}}` |
| `/` | Division | `{{total / count}}` |
| `-` (unary) | Negation | `{{-balance}}` |

Both operands must be numeric. Division by zero returns null.

```yaml
content: "Line total: {{price * quantity}} $"
content: "After discount: {{total - total * discountPercent / 100}} $"
```

### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal | `{{#if status == 'paid'}}` |
| `!=` | Not equal | `{{#if status != 'cancelled'}}` |
| `<` | Less than | `{{#if stock < 5}}` |
| `>` | Greater than | `{{#if total > 1000}}` |
| `<=` | Less or equal | `{{#if quantity <= 10}}` |
| `>=` | Greater or equal | `{{#if rating >= 4}}` |

Comparison rules:
- Numbers: compared by value (`100 == 100.0` is true)
- Strings: ordinal case-sensitive comparison
- Booleans: `==`/`!=` with `true`/`false` literals
- Null: `null == null` is true
- Mixed types: `==` is false, `!=` is true

### Logical Operators

| Operator | Description | Returns |
|----------|-------------|---------|
| `\|\|` | Logical OR / truthy coalescing | First truthy operand, or last |
| `&&` | Logical AND | First falsy operand, or last |
| `!` | Logical NOT | Inverted truthiness |
| `??` | Null coalescing | First non-null operand |

**Key difference between `||` and `??`:**
```yaml
# || catches null AND empty string AND zero AND false
content: "{{name || 'Guest'}}"         # "" -> "Guest", null -> "Guest", 0 -> "Guest"

# ?? catches ONLY null
content: "{{name ?? 'Guest'}}"         # "" -> "", null -> "Guest", 0 -> 0
```

```yaml
# Logical AND for combining conditions
content: "{{#if isPremium && total > 100}}VIP discount!{{/if}}"

# Logical NOT
content: "{{#if !disabled}}Feature enabled{{/if}}"

# Chained null coalescing
content: "{{nickname ?? name ?? 'Anonymous'}}"
```

### Truthiness

| Value | Truthy? |
|-------|---------|
| Non-empty string | Yes |
| Non-zero number | Yes |
| `true` | Yes |
| Non-empty array | Yes |
| Non-empty object | Yes |
| `null` / missing key | No |
| Empty string `""` | No |
| `0` | No |
| `false` | No |
| Empty array `[]` | No |

### Filters

Pipe syntax with three modes:
- Positional only: `{{value | truncate:30}}`
- Named only: `{{value | truncate length:30 suffix:'..'}}`
- Mixed: `{{value | truncate:30 suffix:'..' fromEnd}}`

| Filter | Argument | Description | Example |
|--------|----------|-------------|---------|
| `currency` | — | 2 decimal places | `{{price \| currency}}` -> `"1234.50"` |
| `number` | decimal places (0-20) | N decimal places | `{{rate \| number:4}}` -> `"3.1416"` |
| `upper` | — | Uppercase | `{{name \| upper}}` -> `"JOHN"` |
| `lower` | — | Lowercase | `{{name \| lower}}` -> `"john"` |
| `trim` | — | Trim whitespace | `{{input \| trim}}` |
| `truncate` | length (default 50) | Truncate string | `{{desc \| truncate:20}}` |
| `format` | format string | .NET format string | `{{date \| format:"dd.MM.yyyy"}}` |
| `currencySymbol` | — | ISO 4217 code to symbol | `{{currency \| currencySymbol}}` -> `"$"` |

Truncate options: `suffix` (default `"..."`), `fromEnd` (flag for tail truncation).

```yaml
# Price formatting
content: "Total: {{subtotal * 1.1 | currency}} $"

# Currency symbol from code
content: "{{currencyCode | currencySymbol}} {{amount | currency}}"

# Truncate from end with custom suffix
content: "{{file.path | truncate:20 fromEnd suffix:'...'}}"

# Date formatting
content: "Date: {{orderDate | format:\"dd.MM.yyyy\"}}"
```

### String Literals

Both single and double quotes supported:
```yaml
content: "{{name ?? 'default'}}"
content: '{{name ?? "default"}}'
```

Escape sequences: `\\`, `\"`, `\'`, `\n`, `\t`

### Text Blocks (inline control flow)

#### Conditional Blocks

```yaml
content: "{{#if name}}Hello {{name}}{{else}}Hello guest{{/if}}"
content: "{{#if total > 1000}}Free shipping!{{else}}Shipping: 10${{/if}}"
content: "{{#if status == 'paid'}}Payment received{{else}}Awaiting payment{{/if}}"
content: "{{#if !disabled}}Feature enabled{{/if}}"
content: "{{#if role == 'admin' || role == 'moderator'}}Staff{{else}}User{{/if}}"
```

#### Loop Blocks

```yaml
content: "{{#each items}}{{name}}{{#if @last}}.{{else}}, {{/if}}{{/each}}"
# Output with items=[{name:"A"},{name:"B"},{name:"C"}]: "A, B, C."

# Object iteration with @key
content: "{{#each specs}}{{@key}}: {{.}}, {{/each}}"
# Output with specs={"Color":"Red","Size":"XL"}: "Color: Red, Size: XL, "
```

Loop variables: `@index` (0-based), `@first`, `@last`, `@key` (for objects).

Text blocks can be nested (max depth: 100).

### Expressions in Typed Properties

ALL element properties accept `{{expressions}}`, including typed properties:

```yaml
# Float properties
opacity: "{{theme.textOpacity}}"
grow: "{{layout.growFactor}}"

# Integer properties
maxLines: "{{layout.maxLines}}"
order: "{{item.sortOrder}}"

# Boolean properties
wrap: "{{settings.wordWrap}}"
showText: "{{settings.showBarcodeText}}"

# Enum properties
align: "{{theme.alignment}}"
display: "{{#if hidden}}none{{else}}flex{{/if}}"
position: "{{layout.positionMode}}"
direction: "{{theme.flexDirection}}"

# Size properties
width: "{{layout.cardWidth}}"
height: "{{layout.cardHeight}}"

# With fallback
opacity: "{{theme.opacity ?? 1}}"

# Conditional via text block
showText: "{{#if printMode}}true{{else}}false{{/if}}"
```

How it works: property containing `{{` is preserved as expression during parsing, resolved at render time, then parsed into the target type. If parsing fails, the default value is used.

### Operator Precedence

| Precedence | Operators |
|------------|-----------|
| 0 (highest) | `[]`, `.` (access) |
| 1 | `!`, `-` (unary) |
| 2 | `*`, `/` |
| 3 | `+`, `-` |
| 4 | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| 5 | `&&` |
| 6 | `\|\|` |
| 7 | `??` |
| 8 (lowest) | `\|` (filter pipe) |

### Expression Limits

| Limit | Value |
|-------|-------|
| Max expression length | 2000 characters |
| Max expression depth | 50 |
| Max template nesting depth | 100 |

### Processing Order

1. **Parse** — YAML to AST. Typed properties with `{{` preserved as expressions
2. **Expand** — `type: each` and `type: if` expanded based on data
3. **Resolve** — `{{variable}}` resolved to concrete strings
4. **Materialize** — strings parsed into typed values (float, int, bool, enum)
5. **Layout** — flexbox engine computes positions/sizes
6. **Render** — elements drawn to output

Template caching works because step 1 is separate from 2-6.

## CLI Reference

### Commands

```bash
# Render template to image
flexrender render template.yaml -d data.json -o output.png

# JPEG with quality
flexrender render template.yaml -d data.json -o output.jpg --quality 85

# BMP monochrome (thermal printer)
flexrender render template.yaml -d data.json -o output.bmp --bmp-color monochrome1

# Validate without rendering
flexrender validate template.yaml

# Show template info
flexrender info template.yaml

# Watch and auto-re-render
flexrender watch template.yaml -d data.json -o preview.png

# Debug layout (element bounds)
flexrender debug-layout template.yaml -d data.json
```

### Global Options

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Verbose output |
| `--fonts <dir>` | | Custom fonts directory |
| `--scale <float>` | | Scale factor (e.g., 2.0) |
| `--backend <name>` | `-b` | `skia` (default) or `imagesharp` |

### BMP Color Modes

`bgra32`, `rgb24`, `rgb565`, `grayscale8`, `grayscale4`, `monochrome1`

### Output Formats

Inferred from extension: `.png`, `.jpg`/`.jpeg`, `.bmp`. Override with `--format <png|jpeg|bmp|raw>`.

## Patterns

### Receipt (Thermal Printer)

```yaml
template:
  name: "receipt"
  version: 1

fonts:
  - "assets/fonts/Inter-Regular.ttf"

canvas:
  fixed: width
  width: 380
  background: "#ffffff"

layout:
  - type: flex
    padding: "24 20"
    gap: 12
    children:
      - type: text
        content: "{{shopName}}"
        fontWeight: bold
        size: 1.5em
        align: center

      - type: separator
        style: dashed
        color: "#cccccc"

      - type: each
        array: items
        as: item
        children:
          - type: flex
            direction: row
            justify: space-between
            children:
              - type: text
                content: "{{item.name}}"
              - type: text
                content: "{{item.price | currency}} $"

      - type: separator
        style: solid

      - type: flex
        direction: row
        justify: space-between
        children:
          - type: text
            content: "TOTAL"
            fontWeight: bold
            size: 1.2em
          - type: text
            content: "{{total | currency}} $"
            fontWeight: bold
            size: 1.2em

      - type: flex
        align: center
        children:
          - type: qr
            data: "{{paymentUrl}}"
            size: 120
```

### Label

```yaml
template:
  name: "product-label"
  version: 1

canvas:
  fixed: both
  width: 400
  height: 200
  background: "#ffffff"

layout:
  - type: flex
    direction: row
    padding: "16"
    gap: 16
    children:
      - type: barcode
        data: "{{sku}}"
        format: code128
        width: 150
        height: 80
      - type: flex
        grow: 1
        gap: 4
        children:
          - type: text
            content: "{{productName}}"
            fontWeight: bold
          - type: text
            content: "{{price | currency}} $"
            size: 1.5em
```

### Card with Conditional Content

```yaml
template:
  name: "user-card"
  version: 1

canvas:
  fixed: width
  width: 400
  background: "#f8f9fa"

layout:
  - type: flex
    padding: "24"
    gap: 16
    children:
      - type: flex
        direction: row
        gap: 16
        align: center
        children:
          - type: image
            src: "{{avatarUrl}}"
            width: "64"
            height: "64"
            fit: cover
          - type: flex
            gap: 4
            children:
              - type: text
                content: "{{name}}"
                fontWeight: bold
                size: 1.2em
              - type: text
                content: "{{email}}"
                size: 0.85em
                color: "#666666"

      - type: if
        condition: isPremium
        then:
          - type: flex
            background: "#fef3c7"
            padding: "8 12"
            children:
              - type: text
                content: "Premium Member"
                color: "#92400e"
                size: 0.85em
                fontWeight: semi-bold
```
