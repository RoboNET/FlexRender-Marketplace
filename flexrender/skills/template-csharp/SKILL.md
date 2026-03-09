---
name: template-csharp
description: "Use when building FlexRender templates programmatically in C#, configuring FlexRenderBuilder, integrating via DI, or selecting NuGet packages. Covers AST classes, builder API, content parsers, resource loaders, and AOT-safe patterns."
---

# FlexRender C# Integration

## Overview

Help users build FlexRender templates programmatically in C#, configure the rendering pipeline, integrate with dependency injection, and select the right NuGet packages.

## NuGet Package Selection

Ask what the user needs and recommend the minimal set:

| Scenario | Packages | Install |
|----------|----------|---------|
| Parse YAML only | Core + Yaml | `dotnet add package FlexRender.Core` + `dotnet add package FlexRender.Yaml` |
| Render with Skia | + Skia | `dotnet add package FlexRender.Skia` |
| Render with ImageSharp | + ImageSharp | `dotnet add package FlexRender.ImageSharp` |
| SVG output | + Svg | `dotnet add package FlexRender.Svg` |
| QR codes | + QrCode | `dotnet add package FlexRender.QrCode` |
| Barcodes | + Barcode | `dotnet add package FlexRender.Barcode` |
| SVG elements | + SvgElement | `dotnet add package FlexRender.SvgElement` |
| HarfBuzz shaping | + HarfBuzz | `dotnet add package FlexRender.HarfBuzz` |
| HTTP resources | + Http | `dotnet add package FlexRender.Http` |
| DI integration | + DI | `dotnet add package FlexRender.DependencyInjection` |
| Everything | MetaPackage | `dotnet add package FlexRender.MetaPackage` |

### Backend Comparison

| Backend | Features | Native Deps | Best For |
|---------|----------|-------------|----------|
| Skia (default) | Full: QR, barcode, SVG elements, HarfBuzz, gradients | SkiaSharp native libs | Maximum features |
| ImageSharp | Pure .NET, QR/barcode (no SVG elements) | None | Cross-platform, no native deps |
| SVG | Vector output, QR/barcode/SVG elements | None | Scalable output, web |

## FlexRenderBuilder API

### Without DI

```csharp
using FlexRender;

// Minimal
using var render = new FlexRenderBuilder()
    .WithSkia()
    .Build();

// Full-featured
using var render = new FlexRenderBuilder()
    .WithBasePath("./templates")
    .WithHttpLoader(opts => {
        opts.Timeout = TimeSpan.FromSeconds(60);
        opts.MaxResourceSize = 20 * 1024 * 1024;
    })
    .WithLimits(limits => {
        limits.MaxRenderDepth = 200;
        limits.MaxTemplateFileSize = 2 * 1024 * 1024;
    })
    .WithFilter(new MyCustomFilter())
    .WithSkia(skia => skia
        .WithQr()
        .WithBarcode()
        .WithSvgElement())
    .Build();

// Render from YAML file
byte[] png = await render.RenderFile("receipt.yaml", data);

// Render from YAML string
byte[] png = await render.RenderYaml(yamlString, data);

// Render from pre-parsed template
byte[] png = await render.Render(template, data);
```

### With DI (Microsoft.Extensions.DependencyInjection)

```csharp
services.AddFlexRender(builder => builder
    .WithHttpLoader()
    .WithSkia(skia => skia
        .WithQr()
        .WithBarcode()));

// Inject IFlexRender
public sealed class ReceiptService(IFlexRender render)
{
    public async Task<byte[]> GenerateReceipt(ReceiptData data)
    {
        var templateData = new ObjectValue
        {
            ["shopName"] = (StringValue)data.ShopName,
            ["items"] = new ArrayValue(data.Items.Select(i =>
                new ObjectValue
                {
                    ["name"] = (StringValue)i.Name,
                    ["price"] = (NumberValue)i.Price
                })),
            ["total"] = (NumberValue)data.Total
        };

        return await render.RenderFile("receipt.yaml", templateData);
    }
}
```

### Builder Safety

- `Build()` can only be called once (`_built` flag prevents reuse)
- `WithHttpLoader()` wraps HttpClient creation in try-catch
- `Dispose()` on IFlexRender disposes all registered resource loaders

## Template Caching

Parse once, render many times with different data:

```csharp
// At startup
var parser = new TemplateParser();
var template = await parser.ParseFileAsync("receipt.yaml");

// Per request
byte[] png = await render.Render(template, data);
```

The AST is immutable and thread-safe after parsing.

## Template AST Classes

Build templates programmatically without YAML:

```csharp
var template = new Template
{
    Metadata = new TemplateMetadata { Name = "receipt", Version = 1 },
    Canvas = new CanvasSettings
    {
        Fixed = FixedDimension.Width,
        Width = 380,
        Background = "#ffffff"
    },
    Layout =
    [
        new FlexElement
        {
            Padding = "24 20",
            Gap = "12",
            Children =
            [
                new TextElement
                {
                    Content = "Hello, World!",
                    FontWeight = FontWeight.Bold,
                    Size = "1.5em",
                    Align = TextAlign.Center
                },
                new SeparatorElement
                {
                    Style = SeparatorStyle.Dashed,
                    Color = "#cccccc"
                },
                new QrElement
                {
                    Data = "https://example.com",
                    Size = 120,
                    ErrorCorrection = ErrorCorrectionLevel.M
                }
            ]
        }
    ]
};

byte[] png = await render.Render(template, data);
```

### AST Element Classes

| Class | YAML `type` | Key Properties |
|-------|-------------|----------------|
| `TextElement` | `text` | Content, Font, FontFamily, FontWeight, FontStyle, Size, Color, Align, Wrap, Overflow, MaxLines, LineHeight |
| `FlexElement` | `flex` | Direction, Wrap, Gap, ColumnGap, RowGap, Justify, Align, AlignContent, Overflow, Children |
| `ImageElement` | `image` | Src, Fit |
| `QrElement` | `qr` | Data, Size, ErrorCorrection, Foreground |
| `BarcodeElement` | `barcode` | Data, Format, ShowText, Foreground |
| `SeparatorElement` | `separator` | Orientation, Style, Thickness, Color |
| `TableElement` | `table` | Array, As, Columns, Rows, HeaderFont, HeaderColor, HeaderSize, HeaderBackground |
| `SvgElement` | `svg` | Src, Content, Fit |
| `ContentElement` | `content` | Source, Format, Options |
| `EachElement` | `each` | Array, As, Children |
| `IfElement` | `if` | Condition, Then, ElseIf, Else + 13 comparison operators |

### Base Properties (TemplateElement)

All elements inherit: Padding, Margin, Background, Opacity, BoxShadow, Rotate, Display, Grow, Shrink, Basis, AlignSelf, Order, Width, Height, MinWidth, MaxWidth, MinHeight, MaxHeight, Position, Top, Right, Bottom, Left, AspectRatio, TextDirection.

## Data Objects

```csharp
using FlexRender.Values;

// String
TemplateValue str = (StringValue)"Hello";

// Number
TemplateValue num = (NumberValue)42.5m;

// Boolean
TemplateValue flag = (BoolValue)true;

// Null
TemplateValue nil = NullValue.Instance;

// Array
var arr = new ArrayValue(
    new ObjectValue { ["name"] = "Item 1" },
    new ObjectValue { ["name"] = "Item 2" }
);

// Object (main data container)
var data = new ObjectValue
{
    ["name"] = "John",
    ["age"] = (NumberValue)30,
    ["active"] = (BoolValue)true,
    ["address"] = new ObjectValue
    {
        ["city"] = "Moscow",
        ["zip"] = "101000"
    },
    ["items"] = arr
};
```

## Custom Filters

```csharp
public sealed class PercentFilter : ITemplateFilter
{
    public string Name => "percent";

    public TemplateValue Apply(TemplateValue input, FilterArguments arguments, CultureInfo culture)
    {
        if (input is not NumberValue number)
            return input;

        var decimals = arguments.Positional is NumberValue d ? (int)d.Value : 0;
        return new StringValue(number.Value.ToString($"P{decimals}", culture));
    }
}

// Register
var render = new FlexRenderBuilder()
    .WithFilter(new PercentFilter())
    .WithSkia()
    .Build();
```

Usage in YAML: `{{rate | percent:2}}`

## Content Parsers

```csharp
// Built-in parsers registered via packages:
// FlexRender.Content.Markdown -> "markdown"
// FlexRender.Content.Html -> "html"
// FlexRender.Content.Ndc -> "ndc"

// Custom parser
public sealed class MyParser : IContentParser
{
    public string Format => "myformat";

    public IReadOnlyList<TemplateElement> Parse(
        string text,
        ContentParserContext context,
        IReadOnlyDictionary<string, object>? options = null)
    {
        return [new TextElement { Content = text }];
    }
}
```

## Resource Loaders

| Loader | Handles | Package |
|--------|---------|---------|
| `FileResourceLoader` | Relative file paths | Core |
| `Base64ResourceLoader` | `data:` URIs | Core |
| `EmbeddedResourceLoader` | `embedded://` URIs | Core |
| `HttpResourceLoader` | `http://`, `https://` | Http |

```csharp
builder.WithHttpLoader(opts => {
    opts.Timeout = TimeSpan.FromSeconds(30);
    opts.MaxResourceSize = 10 * 1024 * 1024;
});
```

## Resource Limits

```csharp
builder.WithLimits(limits => {
    limits.MaxTemplateFileSize = 1 * 1024 * 1024;  // 1 MB (default)
    limits.MaxDataFileSize = 10 * 1024 * 1024;     // 10 MB
    limits.MaxTemplateNestingDepth = 100;
    limits.MaxRenderDepth = 100;
    limits.MaxImageSize = 10 * 1024 * 1024;
    limits.MaxFlexLines = 1000;
});
```

Never remove or weaken these limits.

## Render Options

```csharp
var options = new RenderOptions
{
    Format = ImageFormat.Png,
    JpegQuality = 90,
    Scale = 2.0f,
    Culture = new CultureInfo("ru-RU"),
    BmpColorMode = BmpColorMode.Monochrome1
};

byte[] result = await render.RenderFile("template.yaml", data, options);
```

## AOT-Safe Coding Patterns

FlexRender is fully AOT-compatible. When extending it:

- **No reflection** — no `Type.GetType()`, no `Activator.CreateInstance()`
- **No `dynamic`** — use pattern matching instead
- **`sealed` classes** — all concrete classes must be sealed
- **`GeneratedRegex`** — use source-generated regex, not `new Regex()`
- **Null checks** — `ArgumentNullException.ThrowIfNull(param)`
- **Dispose pattern** — `IFlexRender` disposes loaders
- **Switch-based dispatch** — use `switch` on concrete types

```csharp
// AOT-safe pattern matching
static string GetElementType(TemplateElement element) => element switch
{
    TextElement => "text",
    FlexElement => "flex",
    ImageElement => "image",
    _ => "unknown"
};
```

## Complete Example: Receipt Service

```csharp
public sealed class ReceiptService : IDisposable
{
    private readonly IFlexRender _render;
    private readonly Template _template;

    public ReceiptService()
    {
        _render = new FlexRenderBuilder()
            .WithSkia(skia => skia.WithQr().WithBarcode())
            .Build();

        var parser = new TemplateParser();
        _template = parser.ParseFileAsync("templates/receipt.yaml").Result;
    }

    public async Task<byte[]> Generate(Receipt receipt)
    {
        var data = new ObjectValue
        {
            ["shopName"] = (StringValue)receipt.ShopName,
            ["address"] = (StringValue)receipt.Address,
            ["items"] = new ArrayValue(receipt.Items.Select(i =>
                new ObjectValue
                {
                    ["name"] = (StringValue)i.Name,
                    ["price"] = (NumberValue)i.Price,
                    ["qty"] = (NumberValue)i.Quantity
                })),
            ["total"] = (NumberValue)receipt.Total,
            ["paymentUrl"] = (StringValue)receipt.PaymentUrl
        };

        return await _render.Render(_template, data);
    }

    public void Dispose() => _render.Dispose();
}
```
