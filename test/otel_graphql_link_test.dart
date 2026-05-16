// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:gql/ast.dart';
import 'package:gql/language.dart' show parseString;
import 'package:gql_exec/gql_exec.dart' as gql;
import 'package:gql_link/gql_link.dart';
import 'package:otel_graphql/otel_graphql.dart';
import 'package:test/test.dart';

class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

Map<String, Object> _attrs(Span span) =>
    {for (final a in span.attributes.toList()) a.key: a.value};

/// Terminating link the tests parameterize: returns a Stream that
/// emits the configured Response and closes, or errors.
class _FakeTerminatingLink extends Link {
  _FakeTerminatingLink({
    this.response,
    this.error,
  });

  final gql.Response? response;
  final Object? error;

  @override
  Stream<gql.Response> request(gql.Request request,
      [NextLink? forward]) async* {
    if (error != null) {
      throw error!;
    }
    yield response ??
        const gql.Response(
          data: <String, dynamic>{},
          response: <String, dynamic>{},
        );
  }
}

DocumentNode _doc(String src) => parseString(src);

gql.Request _request(String src, {String? name}) => gql.Request(
      operation: gql.Operation(document: _doc(src), operationName: name),
    );

void main() {
  group('OTelGraphqlLink', () {
    late _MemorySpanExporter exporter;
    late OTelGraphqlLink otelLink;

    setUp(() async {
      await OTel.reset();
      exporter = _MemorySpanExporter();
      await OTel.initialize(
        serviceName: 'graphql-otel-test',
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(exporter),
      );
      otelLink = OTelGraphqlLink();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('query emits span with graphql.operation.* attributes', () async {
      final chain = Link.from([otelLink, _FakeTerminatingLink()]);
      await chain
          .request(_request('query GetUser { user { id } }', name: 'GetUser'))
          .drain<void>();

      expect(exporter.spans, hasLength(1));
      final span = exporter.spans.single;
      expect(span.name, equals('query GetUser'));
      final attrs = _attrs(span);
      expect(attrs['graphql.operation.type'], equals('query'));
      expect(attrs['graphql.operation.name'], equals('GetUser'));
      // Document not captured by default.
      expect(attrs.containsKey('graphql.document'), isFalse);
      expect(span.status, isNot(equals(SpanStatusCode.Error)));
    });

    test('mutation operation produces the right type + name', () async {
      final chain = Link.from([otelLink, _FakeTerminatingLink()]);
      await chain
          .request(_request(
            'mutation SignOut { signOut }',
            name: 'SignOut',
          ))
          .drain<void>();

      final span = exporter.spans.single;
      expect(span.name, equals('mutation SignOut'));
      expect(_attrs(span)['graphql.operation.type'], equals('mutation'));
    });

    test('anonymous operation falls back to type-only span name', () async {
      final chain = Link.from([otelLink, _FakeTerminatingLink()]);
      await chain.request(_request('{ ping }')).drain<void>();

      final span = exporter.spans.single;
      expect(span.name, equals('query'));
      final attrs = _attrs(span);
      expect(attrs['graphql.operation.type'], equals('query'));
      expect(attrs.containsKey('graphql.operation.name'), isFalse);
    });

    test('GraphQL response with errors flips span status to Error', () async {
      final chain = Link.from([
        otelLink,
        _FakeTerminatingLink(
          response: const gql.Response(
            errors: [gql.GraphQLError(message: 'no such user')],
            response: <String, dynamic>{},
          ),
        ),
      ]);
      await chain
          .request(_request('query GetUser { user { id } }', name: 'GetUser'))
          .drain<void>();

      final span = exporter.spans.single;
      expect(span.status, equals(SpanStatusCode.Error));
    });

    test('transport error from a downstream link surfaces on the span',
        () async {
      final boom = StateError('connection reset');
      final chain = Link.from([
        otelLink,
        _FakeTerminatingLink(error: boom),
      ]);

      await expectLater(
        chain.request(_request('query Q { ok }', name: 'Q')).drain<void>(),
        throwsA(equals(boom)),
      );

      final span = exporter.spans.single;
      expect(span.status, equals(SpanStatusCode.Error));
      final attrs = _attrs(span);
      expect(attrs['error.type'], equals('StateError'));
      final events = span.spanEvents ?? [];
      expect(events.any((e) => e.name == 'exception'), isTrue);
    });

    test('recordDocument: true captures the printed document, clipped',
        () async {
      final link = OTelGraphqlLink(recordDocument: true, documentMaxLength: 8);
      final chain = Link.from([link, _FakeTerminatingLink()]);
      await chain
          .request(_request(
            'query GetUser { user { id name email phone } }',
            name: 'GetUser',
          ))
          .drain<void>();

      final document =
          _attrs(exporter.spans.single)['graphql.document']! as String;
      expect(document, endsWith('…'));
      expect(document.length, equals(9)); // 8 + ellipsis
    });
  });
}
