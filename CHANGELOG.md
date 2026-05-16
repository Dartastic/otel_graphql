# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-beta.1-wip]

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
- `GraphqlSemantics` — typed attribute-key enum implementing
  `OTelSemantic`, package-local pending a draft OTel GraphQL
  convention upstream.
- Depends on `gql_link` + `gql_exec` (the lightweight
  abstractions), so the package works for both `package:graphql`
  and `package:graphql_flutter` users.
- 6 unit tests cover query / mutation / anonymous / GraphQL-error /
  transport-error / `recordDocument` paths.
