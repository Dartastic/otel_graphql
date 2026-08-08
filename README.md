# otel_graphql

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
