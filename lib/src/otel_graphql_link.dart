// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:gql/ast.dart' show DocumentNode, OperationType;
import 'package:gql/language.dart' show printNode;
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';

/// OpenTelemetry instrumentation for the `gql_link` chain used by
/// `package:graphql` and `package:graphql_flutter`.
///
/// Insert as the **first** link in your chain so its span encloses
/// everything the downstream links (auth, retry, HTTP transport) do:
///
/// ```dart
/// final link = Link.from([
///   OTelGraphqlLink(),
///   HttpLink('https://api.example.com/graphql'),
/// ]);
/// ```
///
/// One span per GraphQL operation; the span lifetime tracks the
/// Link's response Stream. For queries / mutations that's a single
/// emission then close — the span ends on stream done. For
/// subscriptions the span ends when the consumer unsubscribes or
/// the server closes the stream.
///
/// ## Span shape
///
/// | Attribute | Source | When set |
/// |---|---|---|
/// | `graphql.operation.type` | `query` / `mutation` / `subscription` | when the document specifies one |
/// | `graphql.operation.name` | `Operation.operationName` | when present |
/// | `graphql.document` | `printNode(operation.document)` | only when `recordDocument: true` |
///
/// - **Span name**: `<type> <name>` (e.g. `query GetUser`), falling
///   back to the operation type, or `graphql` if even that is unknown.
/// - **Span kind**: default `INTERNAL` — the actual network call is
///   typically wrapped by the underlying HTTP / WebSocket Link's
///   own instrumentation, which gives you a `CLIENT` span as a
///   child of this one.
/// - **Span status**: `Error` if the Response carries GraphQL errors
///   (`response.errors`) or the underlying stream errors, otherwise
///   unset.
///
/// GraphQL **variables are never captured** — there is deliberately
/// no option for it. Variables routinely carry PII and secrets
/// (emails, passwords, tokens, user ids), so capture stays off by
/// design rather than off by default. The document capture
/// ([recordDocument], default `false`) is the only opt-in, and even
/// that can leak schema details and variable *shapes*.
class OTelGraphqlLink extends Link {
  /// Creates the link.
  ///
  /// - [tracer] — defaults to
  ///   `OTel.tracerProvider().getTracer('otel_graphql')`.
  /// - [recordDocument] — when `true`, the printed GraphQL document
  ///   is recorded as `graphql.document`. Off by default because
  ///   documents can leak schema and variable shapes.
  /// - [documentMaxLength] — cap on `graphql.document` when
  ///   recording is enabled. Defaults to 1024.
  OTelGraphqlLink({
    Tracer? tracer,
    this.recordDocument = false,
    this.documentMaxLength = 1024,
  }) : _tracer = tracer ?? OTel.tracerProvider().getTracer('otel_graphql');

  final Tracer _tracer;

  /// Whether to attach the pretty-printed document as
  /// `graphql.document`.
  final bool recordDocument;

  /// Max length for `graphql.document` when recording is enabled.
  final int documentMaxLength;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    if (forward == null) {
      // Terminating link in the chain — nothing to instrument; the
      // execution would error anyway, so just bail.
      return;
    }

    final span = _startSpan(request);

    try {
      await for (final response in forward(request)) {
        if (response.errors != null && response.errors!.isNotEmpty) {
          // Per the GraphQL spec, errors on the Response are
          // partial-failure signals — flag the span as Error on
          // first occurrence but keep emitting.
          _setErrorFromResponse(span, response);
        }
        yield response;
      }
    } catch (error, stackTrace) {
      _setTransportError(span, error, stackTrace);
      rethrow;
    } finally {
      span.end();
    }
  }

  APISpan _startSpan(Request request) {
    final operation = request.operation;
    final operationName = operation.operationName;
    final operationType = operation.getOperationType();

    final typeStr = _typeString(operationType);
    final spanName = _buildSpanName(typeStr, operationName);

    final attrs = <String, Object>{};
    if (typeStr != null) {
      attrs[Graphql.graphqlOperationType.key] = typeStr;
    }
    if (operationName != null) {
      attrs[Graphql.graphqlOperationName.key] = operationName;
    }
    if (recordDocument) {
      attrs[Graphql.graphqlDocument.key] = _clipDocument(operation.document);
    }

    return _tracer.startSpan(
      spanName,
      attributes: OTel.attributesFromMap(attrs),
    );
  }

  void _setErrorFromResponse(APISpan span, Response response) {
    final errs = response.errors!;
    final first = errs.first.message;
    span.setStatus(SpanStatusCode.Error, first);
  }

  void _setTransportError(APISpan span, Object error, StackTrace stackTrace) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorAttributes.errorType.key,
        error.runtimeType.toString(),
      ),
    ]));
    // Spec order: recordException, THEN setStatus.
    span.recordException(error, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, error.toString());
  }

  String? _typeString(OperationType? type) {
    switch (type) {
      case OperationType.query:
        return GraphqlOperationType.query.value;
      case OperationType.mutation:
        return GraphqlOperationType.mutation.value;
      case OperationType.subscription:
        return GraphqlOperationType.subscription.value;
      case null:
        return null;
    }
    // Unreachable; kept to satisfy the analyzer's
    // body_might_complete_normally_nullable check against future
    // OperationType additions.
    // ignore: dead_code
    return null;
  }

  String _buildSpanName(String? type, String? name) {
    if (type != null && name != null) return '$type $name';
    if (type != null) return type;
    if (name != null) return name;
    return 'graphql';
  }

  String _clipDocument(DocumentNode document) {
    final pretty = printNode(document);
    if (pretty.length <= documentMaxLength) return pretty;
    return '${pretty.substring(0, documentMaxLength)}…';
  }
}
