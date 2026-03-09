---
name: content-formats
description: "Use when working with FlexRender content element and content parsers: Markdown, HTML, and NDC (ATM receipt) formats. Covers element mapping, parser options, encoding, and usage in both YAML and C#."
---

# FlexRender Content Formats

## Content Element Overview

The `content` element is a **control-flow element** that embeds dynamically formatted content into a FlexRender template. At render time, the source text or binary data is parsed by a pluggable content parser and expanded into a subtree of standard FlexRender elements (TextElement, FlexElement, ImageElement, etc.). The content element itself does not appear in the final render tree.

### YAML Declaration

```yaml
- type: content
  source: "{{body}}"
  format: markdown
  options:
    # parser-specific key-value options (optional)
```

### Properties

| Property | YAML Name | Type | Default | Description |
|----------|-----------|------|---------|-------------|
| Source | `source` | string | `""` | The content to parse. Supports plain text, `data:` URI binary, `file:` URIs, `text:` prefix, and `{{variable}}` expressions resolving to `string` or `BytesValue` (`byte[]`). |
| Format | `format` | string | `""` | Must match a registered `IContentParser.FormatName` (e.g., `markdown`, `html`, `ndc`). |
| Options | `options` | dict? | `null` | Parser-specific options passed to the content parser. |

### Content Source Resolution

Sources are resolved in this priority order:

| Source Format | Example | Resolved As |
|---------------|---------|-------------|
| Template variable (`BytesValue`) | `source: "{{rawData}}"` | Binary (`byte[]`) -- passed to `IBinaryContentParser` |
| `data:` URI | `source: "data:;base64,SGVsbG8="` | Binary (`byte[]`) -- base64 decoded |
| `file:` scheme | `source: "file:receipt.bin"` | Binary (`byte[]`) -- loaded via resource loaders |
| `text:` prefix | `source: "text:# Hello"` | Text (`string`) -- forces text interpretation |
| File path heuristic | `source: "receipt.md"` | Binary (`byte[]`) -- tries resource loaders, falls back to text |
| Plain text | `source: "**bold text**"` | Text (`string`) -- default fallback |

### C# ContentElement

In C#, the `ContentElement` class holds `Source`, `Format`, and `Options` properties. It is expanded by `TemplateExpander` before layout/rendering.

### Built-in Formats

| Format | NuGet Package | Builder Method | Library Dependency |
|--------|---------------|----------------|--------------------|
| `markdown` | `FlexRender.Content.Markdown` | `.WithMarkdown()` | Markdig |
| `html` | `FlexRender.Content.Html` | `.WithHtml()` | HtmlAgilityPack |
| `ndc` | `FlexRender.Content.Ndc` | `.WithNdc()` | (none) |

---

## Markdown Format

**Package:** `FlexRender.Content.Markdown`
**Parser class:** `MarkdownContentParser` (implements `IContentParser`)
**FormatName:** `"markdown"`
**Library:** Markdig (with `UseAdvancedExtensions()`)

### Registration

```csharp
var render = new FlexRenderBuilder()
    .WithMarkdown()
    .WithSkia()
    .Build();
```

### Supported Syntax and Element Mapping

| Markdown Syntax | FlexRender Element | Notes |
|-----------------|--------------------|-------|
| `# Heading 1` | `TextElement { FontWeight = Bold, Size = "2em" }` | Headings with mixed formatting produce a `FlexElement { Direction = Row }` wrapping multiple `TextElement` children |
| `## Heading 2` | `TextElement { FontWeight = Bold, Size = "1.5em" }` | |
| `### Heading 3` | `TextElement { FontWeight = Bold, Size = "1.2em" }` | |
| `#### Heading 4` | `TextElement { FontWeight = Bold, Size = "1em" }` | |
| `##### Heading 5+` | `TextElement { FontWeight = Bold, Size = "0.9em" }` | |
| `**bold**` | `TextElement { FontWeight = Bold }` | |
| `*italic*` | `TextElement { FontStyle = Italic }` | |
| `***bold italic***` | `TextElement { FontWeight = Bold, FontStyle = Italic }` | |
| `` `inline code` `` | `TextElement { Background = "#f0f0f0" }` | |
| `- item` / `* item` | `FlexElement { Direction = Column, Gap = "4" }` | Each item prefixed with bullet character. Ordered lists use `"1. "`, `"2. "` etc. |
| `> blockquote` | `FlexElement { Padding = "0 0 0 12", Background = "#f5f5f5" }` | |
| `---` (thematic break) | `SeparatorElement` | |
| `![alt](url)` | `ImageElement { Src = url }` | |
| `[link text](url)` | Rendered as plain text (link text only) | URLs are not preserved in rendered output |
| Fenced code blocks | `FlexElement { Background = "#f0f0f0", Padding = "8" }` containing `TextElement` | |

### Paragraph Handling

- A paragraph with a single inline produces a single `TextElement`.
- A paragraph with mixed formatting (e.g., `Hello **world**`) produces a `FlexElement { Direction = Row }` containing multiple `TextElement` children.

### Depth Limit

Maximum recursion depth is 64 levels to prevent stack overflow on deeply nested input.

### Limitations

- No table support (tables are not converted).
- Link URLs are discarded -- only the link text is rendered.
- No syntax highlighting for code blocks.
- Images reference URLs but rendering depends on registered resource loaders.

### YAML Example

```yaml
layout:
  - type: content
    source: "{{orderDetails}}"
    format: markdown
    padding: "12 16"
```

Data:
```json
{
  "orderDetails": "## Items\n\n- Widget A -- $9.99\n- **Gadget B** -- $24.99\n\n> Total: **$34.98**"
}
```

---

## HTML Format

**Package:** `FlexRender.Content.Html`
**Parser class:** `HtmlContentParser` (implements `IContentParser`)
**FormatName:** `"html"`
**Library:** HtmlAgilityPack

### Registration

```csharp
var render = new FlexRenderBuilder()
    .WithHtml()
    .WithSkia()
    .Build();
```

### Supported Tags and Element Mapping

| HTML Tag | FlexRender Element | Notes |
|----------|--------------------|-------|
| `<h1>` through `<h6>` | `TextElement { FontWeight = Bold, Size = "2em"/"1.5em"/"1.2em"/"1em"/"0.9em"/"0.8em" }` | Mixed inline content wrapped in `FlexElement { Direction = Row }` |
| `<p>` | `TextElement` or `FlexElement { Direction = Row }` | Single child unwrapped, multiple children wrapped in row |
| `<b>`, `<strong>` | `TextElement { FontWeight = Bold }` | Inline formatting inherited by children |
| `<i>`, `<em>` | `TextElement { FontStyle = Italic }` | |
| `<code>` (inline) | `TextElement { Background = "#f0f0f0" }` | Only when not inside `<pre>` |
| `<pre>` | `FlexElement { Background = "#f0f0f0", Padding = "8" }` containing `TextElement` | Preserves whitespace |
| `<br>` | `TextElement { Content = "\n" }` | |
| `<hr>` | `SeparatorElement` | |
| `<img>` | `ImageElement { Src, ImageWidth, ImageHeight }` | Width/height parsed from attributes |
| `<a>` | Styled inline text with `Color = "#0066cc"` | URLs discarded, text rendered with link color |
| `<ul>` | `FlexElement { Direction = Column, Gap = "4" }` | Items prefixed with bullet |
| `<ol>` | `FlexElement { Direction = Column, Gap = "4" }` | Items prefixed with `"1. "`, `"2. "` etc. |
| `<blockquote>` | `FlexElement { Padding = "0 0 0 12", Background = "#f5f5f5" }` | |
| `<div>`, `<section>`, `<article>`, `<nav>`, `<header>`, `<footer>`, `<main>`, `<aside>` | `FlexElement { Direction = Column }` | Container elements; inline styles applied |
| `<span>` | Inline formatting pass-through | Applies inline styles from `style` attribute |

### Ignored Tags

These tags are silently skipped: `script`, `style`, `head`, `meta`, `link`, `title`.

### Passthrough Tags

These tags are transparent wrappers -- children are processed directly: `html`, `body`.

### Supported CSS Properties (via `style` attribute)

The HTML parser reads inline `style` attributes and maps CSS properties to FlexRender properties:

| CSS Property | FlexRender Mapping | Notes |
|--------------|--------------------|-------|
| `color` | `TextElement.Color` | Any CSS color value |
| `font-size` | `TextElement.Size` | Passed through as string (e.g., `"1.3em"`) |
| `font-weight` | `TextElement.FontWeight` | `bold`, `normal`, or numeric 100-900 mapped to enum |
| `font-style` | `TextElement.FontStyle` | `italic`, `oblique`, `normal` |
| `background-color` / `background` | `TextElement.Background` or `FlexElement.Background` | |
| `text-align` | `TextElement.Align` | `left`, `center`, `right` |
| `padding` | `FlexElement.Padding` | On container elements (`div`, etc.) |

### Depth Limit

Maximum recursion depth is 64 levels.

### YAML Example

```yaml
layout:
  - type: content
    source: "{{productInfo}}"
    format: html
    padding: "8"
```

Data:
```json
{
  "productInfo": "<p>Price: <b style=\"color: #E91E63; font-size: 1.3em;\">$29.99</b></p>"
}
```

---

## NDC Format

**Package:** `FlexRender.Content.Ndc`
**Parser class:** `NdcContentParser` (implements both `IContentParser` and `IBinaryContentParser`)
**FormatName:** `"ndc"`
**Library:** None (pure C# implementation)

### What is NDC?

NDC (NCR Direct Connect) is the proprietary ATM communication protocol used by NCR banking terminals worldwide. It defines a binary/text printer data stream format for generating receipts on ATM thermal printers. NDC data contains escape sequences for character set switching, spacing control, form feeds, barcode printing, and more.

FlexRender's NDC parser converts these printer data streams into visual receipt images, enabling digital archival, dispute resolution, and receipt preview in banking applications.

### Registration

```csharp
var render = new FlexRenderBuilder()
    .WithNdc()
    .WithSkia()
    .Build();
```

The `.WithNdc()` extension registers the parser as both `IContentParser` (text input) and `IBinaryContentParser` (binary input). When binary data is provided, it is first decoded using the configured `input_encoding` (default: Latin-1) before being parsed as text.

### NDC Data Stream Structure

An NDC printer data stream is a sequence of printable characters interspersed with control characters and ESC sequences:

#### Control Characters

| Character | Hex | Name | Description |
|-----------|-----|------|-------------|
| LF | `0x0A` | Line Feed | Ends the current line, starts a new one |
| CR | `0x0D` | Carriage Return | Consumed with optional following LF |
| FF | `0x0C` | Form Feed | Ends line and inserts a `SeparatorElement` (visual page break) |
| HT | `0x09` | Horizontal Tab | Advances to next tab stop (every 8 columns) |
| SO | `0x0E` | Shift Out | Followed by a count character; inserts N spaces (1-15) |
| GS | `0x1D` | Group Separator | Field separator -- followed by field ID digit; no visual output |
| ESC | `0x1B` | Escape | Introduces an escape sequence (see below) |

#### SO Space Count Encoding

The byte following SO encodes the number of spaces:

| Character | Spaces |
|-----------|--------|
| `'1'`-`'9'` | 1-9 |
| `':'` | 10 |
| `';'` | 11 |
| `'<'` | 12 |
| `'='` | 13 |
| `'>'` | 14 |
| `'?'` | 15 |

#### ESC Sequences

| Sequence | Format | Description | FlexRender Handling |
|----------|--------|-------------|---------------------|
| `ESC ( X` | Primary charset select | Switches to charset `X` | `CharsetSwitch` token -- applies charset-specific styling |
| `ESC ) X` | Secondary charset select | Switches to charset `X` | `CharsetSwitch` token -- same as primary |
| `ESC k <type> <data> ESC \` | Print barcode | Type: `0`=UPC-A, `1`=UPC-E, `2`=EAN-13, `3`=EAN-8, `4`=Code39, `5`=Interleaved 2of5, `6`=Codabar | Produces `BarcodeElement` |
| `ESC [ <n> q` | Set right margin | Sets line width to `n` columns (clamped 1-132) | Updates column wrapping width |
| `ESC [ <n> p` | Set left margin | Sets left margin | Not yet implemented |
| `ESC [ <n> r` | Set lines per inch | Vertical density | Ignored (no visual effect) |
| `ESC % <3-digit>` | Select code page | OS/2 code page selection | Ignored |
| `ESC 2` | International charset | Select international character set | Ignored |
| `ESC 3` | Arabic charset | Select Arabic character set | Ignored |
| `ESC e <pos>` | Barcode HRI position | Human-readable interpretation position | Ignored |
| `ESC w <width>` | Barcode width | Barcode element width | Ignored |
| `ESC h <3-digit>` | Barcode height | Barcode horizontal height | Ignored |
| `ESC G <name> ESC \` | Print graphics | Print stored graphics by filename | Ignored |
| `ESC / <x> <y>` | Print bit image | Print downloadable bit image | Ignored |
| `ESC p ... ESC \` | Print cheque image | Cheque/document image | Ignored |
| `ESC & ... ESC \` | Define charset | Define downloadable character set | Ignored |
| `ESC * ... ESC \` | Define bit image | Define downloadable bit image | Ignored |
| `ESC q <0/1>` | Dual-sided printing | Select front/back printing | Ignored |

### Parser Options

The `options` block in YAML configures the NDC parser behavior:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `columns` | int | `40` | Maximum characters per line. Lines exceeding this width are auto-wrapped. Typical ATM receipt widths: 32, 40, or 44 columns. |
| `input_encoding` | string | `"latin1"` | Byte encoding for binary input. Supported values: `latin1` / `iso-8859-1`, `utf-8` / `utf8`, `ascii`. Unrecognized values fall back to Latin-1. |
| `font_family` | string | null | Global monospace font family for all text (e.g., `"JetBrains Mono"`, `"Courier New"`). |
| `char_width_ratio` | double | `0.6` | Character width as a fraction of font size. Used for auto font size calculation: `fontSize = canvasWidth / (columns * charWidthRatio)`. |
| `charsets` | dict | `{}` | Per-charset style overrides keyed by designator character. See [Charset Style Properties](#charset-style-properties). |

### Charset Style Properties

Each charset designator (e.g., `"1"`, `"I"`, `">"`) can be configured with individual styling in the `charsets` dictionary:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `font` | string | null | Font registration name (e.g., `"bold"`, `"default"`). Maps to `TextElement.Font`. |
| `font_family` | string | null | Font family override for this charset. Takes precedence over the global `font_family`. |
| `font_style` | string | null | One of: `"bold"`, `"italic"`, `"bold-italic"` / `"bolditalic"`, `"regular"`. Maps to `FontWeight` and `FontStyle` on the text element. |
| `font_size` | int | null | Explicit font size in pixels. Overrides auto-calculated font size. |
| `color` | string | null | Text color in hex format (e.g., `"#333333"`). |
| `encoding` | string | `"none"` | Character encoding for this charset. Key values: `"qwerty-jcuken"` (Cyrillic transliteration), `"none"` (passthrough), `"ascii"` (passthrough). |
| `uppercase` | bool | `false` | Convert all text in this charset to uppercase. |
| `bold` | bool | (legacy) | Legacy property. `bold: true` is equivalent to `font_style: "bold"` and sets `font: "bold"`. Use `font_style` for new templates. |

### QWERTY-JCUKEN Cyrillic Encoding

NDC terminals cannot natively transmit Cyrillic characters. Instead, Russian text is encoded using the QWERTY-to-JCUKEN keyboard layout mapping. Lowercase Latin letters on a QWERTY keyboard are mapped to the corresponding Cyrillic letters on a JCUKEN keyboard layout:

**Only lowercase Latin letters are mapped.** Uppercase Latin letters are preserved as-is -- they represent actual Latin characters in NDC data (e.g., brand names, card types), not Cyrillic.

#### Full Mapping Table

| Latin (QWERTY) | Cyrillic (JCUKEN) | Latin (QWERTY) | Cyrillic (JCUKEN) |
|----------------|-------------------|----------------|-------------------|
| `q` | `й` | `a` | `ф` |
| `w` | `ц` | `s` | `ы` |
| `e` | `у` | `d` | `в` |
| `r` | `к` | `f` | `а` |
| `t` | `е` | `g` | `п` |
| `y` | `н` | `h` | `р` |
| `u` | `г` | `j` | `о` |
| `i` | `ш` | `k` | `л` |
| `o` | `щ` | `l` | `д` |
| `p` | `з` | `\|` | `ж` |
| `{` | `х` | `` ` `` | `э` |
| `}` | `ъ` | `z` | `я` |
| `x` | `ч` | `~` | `б` |
| `c` | `с` | `DEL (0x7F)` | `ю` |
| `v` | `м` | | |
| `b` | `и` | | |
| `n` | `т` | | |
| `m` | `ь` | | |

When `uppercase: true` is set on a charset, all mapped Cyrillic characters are converted to uppercase. Non-mapped characters (digits, punctuation, uppercase Latin) are also uppercased.

### Auto Font Size Calculation

When the content element has a known parent width (from canvas or parent element), the parser automatically calculates font size:

```
fontSize = canvasWidth / (measuredColumns * charWidthRatio)
```

Where `measuredColumns` is the actual maximum line width found in the data (not the configured `columns` value). This ensures the receipt text fits the available width. The root `FlexElement` is set to `fontSize: "fit-content"`.

### Element Output

The NDC parser produces a `FlexElement { Direction = Column }` as the root, containing:

- **Lines:** `FlexElement { Direction = Row, Align = Baseline }` -- each line of the receipt
- **Text segments:** `TextElement { Wrap = false }` -- with charset-specific font, color, weight, style
- **Form feeds:** `SeparatorElement` -- visual page/section breaks
- **Barcodes:** `BarcodeElement { Data, Format }` -- embedded barcodes

Empty lines are preserved with a single space character to maintain line height.

Lines exceeding the configured `columns` width are automatically wrapped at column boundaries.

### Barcode Type Mapping

| NDC Type | Code | FlexRender Format |
|----------|------|-------------------|
| UPC-A | `0` | `BarcodeFormat.Upc` |
| UPC-E | `1` | `BarcodeFormat.Upc` |
| JAN13/EAN-13 | `2` | `BarcodeFormat.Ean13` |
| JAN8/EAN-8 | `3` | `BarcodeFormat.Ean8` |
| Code 39 | `4` | `BarcodeFormat.Code39` |
| Interleaved 2 of 5 | `5` | `BarcodeFormat.Code128` |
| Codabar | `6` | `BarcodeFormat.Code128` |

### YAML Example: NDC Receipt with Cyrillic

```yaml
canvas:
  fixed: width
  width: 384
  background: "#ffffff"

fonts:
  - "assets/fonts/JetBrainsMono-Regular.ttf"
  - "assets/fonts/JetBrainsMono-Bold.ttf"

layout:
  - type: content
    source: "{{receiptData}}"
    format: ndc
    options:
      columns: 40
      input_encoding: latin1
      font_family: "JetBrains Mono"
      charsets:
        "1":
          encoding: "qwerty-jcuken"
          font_style: bold
        "I":
          encoding: "qwerty-jcuken"
          uppercase: true
          color: "#333333"
```

### C# Example: NDC with Binary Data

```csharp
var render = new FlexRenderBuilder()
    .WithNdc()
    .WithSkia(skia => skia.WithBarcode())
    .Build();

// Binary NDC data from ATM
byte[] ndcBytes = GetNdcPrinterData();

var data = new ObjectValue
{
    ["receiptData"] = new BytesValue(ndcBytes)
};

using var image = render.RenderYaml(templateYaml, data);
image.Save("receipt.png");
```

### C# Example: NDC with Data URI

```csharp
// NDC data embedded as base64 in JSON
var jsonData = """
{
  "receiptData": "data:application/octet-stream;base64,G1sxfjQwHSgxHQ=="
}
""";
```

---

## Custom Content Parsers

You can implement custom content parsers by implementing `IContentParser` (for text input) and optionally `IBinaryContentParser` (for binary input).

### IContentParser Interface

```csharp
public interface IContentParser
{
    /// <summary>
    /// Gets the format name this parser handles (e.g., "markdown", "xml").
    /// </summary>
    string FormatName { get; }

    /// <summary>
    /// Parses formatted text into template elements.
    /// </summary>
    /// <param name="text">The formatted text to parse.</param>
    /// <param name="context">Template metadata: canvas settings, parent width.</param>
    /// <param name="options">Optional key-value options from the YAML options block.</param>
    /// <returns>List of renderable elements (TextElement, FlexElement, etc.).</returns>
    IReadOnlyList<TemplateElement> Parse(
        string text,
        ContentParserContext context,
        IReadOnlyDictionary<string, object>? options = null);
}
```

### IBinaryContentParser Interface

```csharp
public interface IBinaryContentParser
{
    string FormatName { get; }

    IReadOnlyList<TemplateElement> Parse(
        ReadOnlyMemory<byte> data,
        ContentParserContext context,
        IReadOnlyDictionary<string, object>? options = null);
}
```

### ContentParserContext

```csharp
public sealed record ContentParserContext
{
    /// <summary>Canvas settings (width, height, background).</summary>
    public CanvasSettings? Canvas { get; init; }

    /// <summary>The template being rendered.</summary>
    public Template? Template { get; init; }

    /// <summary>
    /// Computed effective width of the parent element in pixels.
    /// Used for auto-sizing calculations.
    /// </summary>
    public int? ParentWidth { get; init; }
}
```

### Registration

```csharp
// Text-only parser
var render = new FlexRenderBuilder()
    .WithContentParser(new MyCustomParser())
    .WithSkia()
    .Build();

// Text + binary parser (same instance can implement both)
var parser = new MyBinaryParser();
var render = new FlexRenderBuilder()
    .WithContentParser(parser)
    .WithBinaryContentParser(parser)
    .WithSkia()
    .Build();
```

### Implementation Rules

- Return only renderable elements: `TextElement`, `FlexElement`, `ImageElement`, `SeparatorElement`, `BarcodeElement`, etc.
- Do NOT return control-flow elements (`EachElement`, `IfElement`, `ContentElement`) -- they will not be expanded.
- Throw `ArgumentNullException` when `text` or `data` is null.
- Return an empty list for whitespace-only input.
- Respect the `options` dictionary for parser-specific configuration.
- Use `context.ParentWidth` and `context.Canvas?.Width` for layout-aware calculations (e.g., auto font sizing).

---

## Usage Examples

### All Three Formats in One Template

```csharp
var render = new FlexRenderBuilder()
    .WithMarkdown()
    .WithHtml()
    .WithNdc()
    .WithSkia(skia => skia.WithBarcode())
    .Build();
```

```yaml
canvas:
  fixed: width
  width: 400
  background: "#ffffff"

layout:
  # Markdown section
  - type: content
    source: "{{markdownBody}}"
    format: markdown
    padding: "12"

  - type: separator

  # HTML section
  - type: content
    source: "{{htmlContent}}"
    format: html
    padding: "8"

  - type: separator

  # NDC receipt section
  - type: content
    source: "{{receiptData}}"
    format: ndc
    options:
      columns: 40
      font_family: "JetBrains Mono"
      charsets:
        "1":
          encoding: "qwerty-jcuken"
```

### Data Binding

```csharp
var data = new ObjectValue
{
    // String for markdown/html
    ["markdownBody"] = new StringValue("## Order\n\n- Item A\n- **Item B**"),
    ["htmlContent"] = new StringValue("<p>Status: <b style=\"color: green;\">Confirmed</b></p>"),

    // Binary for NDC
    ["receiptData"] = new BytesValue(ndcBytes)
};

using var image = render.RenderYaml(templateYaml, data);
```

### Loading Content from Files

```yaml
# Load markdown from file
- type: content
  source: "file:content/body.md"
  format: markdown

# Load NDC binary from file
- type: content
  source: "file:receipts/receipt001.bin"
  format: ndc
  options:
    input_encoding: latin1
    columns: 40
```
