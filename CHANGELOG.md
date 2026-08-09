# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-10

### Changed

- Semantic conventions updated to the current OTel registry: deprecated
  attribute keys are no longer emitted (`db.system` -> `db.system.name`,
  `db.operation` -> `db.operation.name`, `rpc.system` -> `rpc.system.name`,
  with `rpc.service` folded into a fully-qualified `rpc.method`).
- Adopted the upstream API's `Graphql` semconv enum (and
  `GraphqlOperationType` values); the package-local
  `GraphqlSemantics` enum is deleted. Emitted keys are unchanged
  (`graphql.operation.type`, `graphql.operation.name`,
  `graphql.document` — they match the registry exactly).
- README made vendor-neutral (no backend product names).
- Dependency floors raised to `dartastic_opentelemetry ^1.1.0-beta.12` and
  `dartastic_opentelemetry_api ^1.0.0-rc.1`. The previous floors declared
  compatibility with API versions that predate the semconv enums this
  package uses and could not actually resolve-and-compile.
- `repository` URL corrected to the canonical `Dartastic` org casing so
  pub.dev repository verification succeeds.

### Added

- `OTelGraphqlLink` — a `gql_link` `Link` that emits one span per
  GraphQL operation. Sets `graphql.operation.type`,
  `graphql.operation.name`, and optionally `graphql.document`
  (off by default — documents can leak schema and variable
  shapes). Span name follows the proposed OTel GraphQL semconv
  pattern (`<type> <name>`, e.g. `query GetUser`).
- Span lifecycle tracks the Link's response stream — query /
  mutation spans end right after the response, subscription spans
  end when the consumer cancels or the server closes.
- GraphQL errors inside a response flip span status to Error but
  the stream keeps flowing — partial failures still surface the
  rest of the data path.
- Transport errors from downstream links flow through
  `recordException` + `setStatus(Error)` in OTel-spec order, with
  `error.type` set from the exception's runtime class.
- GraphQL variables are never captured — deliberately no option for
  it (variables routinely carry PII and secrets); documented in the
  README and API docs. `graphql.document` capture remains opt-in and
  off by default.
- Depends on `gql_link` + `gql_exec` (the lightweight
  abstractions), so the package works for both `package:graphql`
  and `package:graphql_flutter` users.
- 6 unit tests cover query / mutation / anonymous / GraphQL-error /
  transport-error / `recordDocument` paths.
- `example/main.dart` — minimal runnable link chain (in-memory
  terminating link, no server needed).
