// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Typed attribute keys for GraphQL instrumentation.
///
/// Tracks the OTel GraphQL semantic-convention proposal
/// (https://opentelemetry.io/docs/specs/semconv/graphql/), which is
/// still draft at the time of writing. When/if the upstream API
/// adds a `GraphQL` enum, the keys here will be `@Deprecated`-ed in
/// favor of it.
enum GraphqlSemantics implements OTelSemantic {
  /// `query` / `mutation` / `subscription`.
  operationType('graphql.operation.type'),

  /// The user-given operation name (e.g. `GetUser`). Null when the
  /// document is anonymous.
  operationName('graphql.operation.name'),

  /// The pretty-printed GraphQL document. Only set when the link is
  /// constructed with `recordDocument: true` — document text can
  /// leak schema details and variable shapes, so it stays off by
  /// default.
  document('graphql.document');

  const GraphqlSemantics(this.key);

  @override
  final String key;

  @override
  String toString() => key;
}
