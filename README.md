<!-- dartastic-header:start -->
# OpenTelemetry instrumentation for `gql`

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenTelemetry Specification](https://img.shields.io/badge/OpenTelemetry-Specification-blueviolet)](https://opentelemetry.io/docs/specs/otel/)

`otel_graphql` is an [OpenTelemetry](https://opentelemetry.io/) instrumentation for `gql` that
easily adds standard observability to applications that use `gql`.  This package depends on 
[dartastic_opentelemetry_api](https://pub.dev/packages/dartastic_opentelemetry_api).

This package can be used with any OTel backend because it's compliant with the OpenTelemetry Specification.

This package supports Android, iOS, Linux, macOS, Web and Windows, for versions of `gql` that support those platforms. It is WASM-ready.

This Apache-2.0 package is professionally maintained and supported with 💙 by Michael Bushe,
Dart and Flutter Maintainer at OpenTelemetry and the creator of [dartastic_opentelemetry](https://pub.dev/packages/dartastic_opentelemetry)
and [dartastic_opentelemetry_api](https://pub.dev/packages/dartastic_opentelemetry_api). This package is professionally supported by
[Dartastic.io](https://dartastic.io).

---
## Dartastic.io: AI Code Healing and Real User Monitoring for Flutter

**See what your users experience. Find problems with Flutter apps in production. Fix them with AI.**

[Dartastic.io](https://dartastic.io) brings AI code healing, real user monitoring, and OpenTelemetry observability together in one platform built for Dart and Flutter. (Patents pending)

![Dartastic AI answering "Why did crashes jump after the last release?" over a Flutter App Health dashboard](https://dartastic.io/img/pub-dev/HomePageCrashesQuestion.png)

### Dartastic AI — From Production Problems to Code Fixes

Dartastic AI analyzes production telemetry alongside your application source code to diagnose problems and propose fixes.

- **Investigate production issues** using crashes, errors, traces, metrics, and real user telemetry.
- **Find the offending code** by connecting observed problems with your application's source in Dartastic Pub or your source code repos.
- **Generate code patches** that address the underlying problems.
- **Create actionable issues** in your issue tracker, complete with findings and the proposed code patch.

### Dartastic RUM — See What Your Users See

Understand how people actually experience your Flutter application.

- **Replay user sessions** in the Dartastic Observatory session player.
- **Choose your replay fidelity**, from privacy-preserving widget outlines to pixel-level reproductions of the user experience.
- **Investigate real user problems** using session replay and production observability data.

![Dartastic RUM Session Replay](https://dartastic.io/img/pub-dev/session-replay.png)

### Dartastic Observatory — Observability Built for Flutter

A complete observability backend where Flutter and Dart are first-class citizens.

- **Flutter-specific dashboards** for application performance, health, and reliability.
- **Alerts and notifications** through email, Slack, and PagerDuty.
- **Dartastic Cloud Observatory** — Start with a 30-day free trial on isolated, shared infrastructure, as low as $39/mo.
- **Dartastic Hosted Observatory** — Run the observability stack in a private managed environment, sized from Mini to Enterprise XL.
- **Dartastic Self-Hosted Observatory** — The whole platform inside your own network. Your keys, your cluster, with nothing leaving your perimeter.

### Dartastic Native OTel Runtime — Native OpenTelemetry Performance

Collect production telemetry without burdening Flutter's main isolate.

- **Native OpenTelemetry runtime** that moves telemetry processing off the main isolate.
- **Native crash reporting** for problems that Dart can't catch.
- **Widget performance diagnostics** to identify janky widgets.
- **On-device PII filtering** before sensitive data leaves your application.
- **Source-level error diagnostics** powered by the Dartastic Symbolizer API.
- **Platform-native metrics** for iOS, Android, and Linux, including iOS MetricKit and Android Vitals.
- **OpenTelemetry compatibility** — Send telemetry to Dartastic Observatory or any OpenTelemetry platform.

### Dartastic Labs — OpenTelemetry Integrations

Instrument more of your application without writing everything yourself.

- **650+ open-source integrations** for Dart and Flutter libraries and services, including Dio, Shelf, Logger, Anthropic, AWS, Azure, and Stripe. Look for otel_* on pub.dev.

### More Dartastic Tools

**[Dartastic Pub](https://dartastic.io/pub)**

A private Dart package registry for sharing packages and plugins with your team, partners, and customers.

**[Dartastic Symbolizer](https://dartastic.io/symbolizer)**

Turn production errors into lines of source code through a web API, while keeping your source code artifacts private.

### Professional Support and Training

Dartastic.io offers commercial support for the open-source `dartastic_opentelemetry` and `dartastic_opentelemetry_api` packages and the complete Dartastic product suite.

- **Professional support** with available around-the-clock coverage and response times under four hours on qualifying plans.
- **OpenTelemetry training** for teams instrumenting Dart, Flutter, mobile, and web applications.

### Open Standards. No Mandatory Backend.

The Dartastic OpenTelemetry API and SDK are open source and standards-based. You can use them independently of Dartastic's commercial services and send telemetry to any compatible OpenTelemetry backend.

Dartastic's commercial products add native performance, advanced diagnostics, session replay, AI-assisted remediation, and managed observability services.

**[Explore Dartastic.io](https://dartastic.io)**

---
<!-- dartastic-header:end -->

OpenTelemetry instrumentation for the `gql_link` chain used by
[`package:graphql`](https://pub.dev/packages/graphql) and
[`package:graphql_flutter`](https://pub.dev/packages/graphql_flutter).
Built on the
[Dartastic OpenTelemetry SDK](https://pub.dev/packages/dartastic_opentelemetry).

Insert one `Link` at the head of your chain and every GraphQL
operation emits a span with the operation type, name, and (opt-in)
the printed document.

```dart
final link = Link.from([
  OTelGraphqlLink(),
  HttpLink('https://api.example.com/graphql'),
]);
final client = GraphQLClient(link: link, cache: GraphQLCache());
```

Works for both pure-Dart `graphql` apps (servers, CLIs) and
Flutter apps that use `graphql_flutter`. Flutter apps may prefer
`otel_graphql_flutter` (the matching overlay) to wire
`graphql_flutter` in one step.

## Why

GraphQL operations are coarser than HTTP requests — one `POST
/graphql` can be any of hundreds of operations the front end
issues. If you only have HTTP spans, every span has the same name
and you can't compare latency across operations. This Link gives
you one span per *operation name*, so a span-by-name view in your
tracing backend slices cleanly by GraphQL endpoint.

The integration is **opt-in**: the OTel SDK does not depend on
`gql_link` or `graphql`. Add this package only when you want it.

## Span shape

| Attribute | Source | When set |
|---|---|---|
| `graphql.operation.type` | `query` / `mutation` / `subscription` | when the document specifies one |
| `graphql.operation.name` | `Operation.operationName` | when present (anonymous operations don't set it) |
| `graphql.document` | `printNode(operation.document)` (clipped) | only when `recordDocument: true` |

- **Span name**: `<type> <name>` (e.g. `query GetUser`), falling
  back to the operation type alone for anonymous operations,
  or `graphql` if even that is unknown.
- **Span kind**: default `INTERNAL`. The actual network call is
  usually wrapped by the underlying HTTP / WebSocket Link's own
  instrumentation — that produces a `CLIENT` span as a child of
  this one.
- **Span status**: `Error` if the response carries GraphQL errors
  (`Response.errors`) or the underlying stream throws, otherwise
  unset.

## Lifecycle

The Link emits a span when an operation enters, and ends it when
the response stream closes:

- **Query / mutation**: single-emission stream — span ends right
  after the response is yielded.
- **Subscription**: multi-emission stream — span ends when the
  consumer cancels or the server closes the stream.

GraphQL errors *inside* a response (partial failures) flip the
span status to Error on first occurrence but the stream keeps
flowing — the trace still sees the rest of the data path.

## Variables are never captured

There is deliberately **no option** to record GraphQL variables.
Variables routinely carry PII and secrets — emails, passwords,
auth tokens, user ids — so variable capture is off by design, not
merely off by default. If you need a specific, known-safe value on
the span, add it yourself from your own code where you can see
what it is.

The one opt-in is `recordDocument` (default `false`), which
records the *document text* (the operation shape, with variable
references like `$id`, not values). Even that stays off by default
because documents can leak schema details.

## Configuration

| Constructor arg | Default | Effect |
|---|---|---|
| `tracer` | `OTel.tracerProvider().getTracer('otel_graphql')` | The tracer that emits the spans. |
| `recordDocument` | `false` | Capture the pretty-printed GraphQL document as `graphql.document`. Off because documents can leak schema details and variable shapes. |
| `documentMaxLength` | `1024` | Cap on `graphql.document` when recording is enabled. |

## Caveats

- Place the OTel link **first** in the chain so its span encloses
  whatever auth / retry / HTTP links do downstream.
- Variable values are never captured — only the document text (and
  only when explicitly opted in). This is intentional: variables
  are the most reliable place for user data to live in a GraphQL
  request.
- The link calls `OTel.tracerProvider().getTracer(...)` in its
  constructor — `OTel.initialize()` must have run first.

## License

Apache 2.0 — see `LICENSE`.
