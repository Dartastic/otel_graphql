// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

// Minimal runnable example: put [OTelGraphqlLink] FIRST in the link
// chain so its span encloses everything downstream (auth, retry, the
// HTTP/WebSocket transport).
//
// In a real app the terminating link is your transport — e.g.
// `HttpLink('https://api.example.com/graphql')` from
// `package:graphql` / `package:gql_http_link`. Here a tiny in-memory
// link stands in so the example runs without a server.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:gql/language.dart' show parseString;
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:otel_graphql/otel_graphql.dart';

Future<void> main() async {
  // 1. Bring up OTel first so trace context is flowing before the
  //    first operation executes.
  await OTel.initialize(serviceName: 'graphql-example');

  // 2. Compose the chain: OTelGraphqlLink first, transport last.
  final link = Link.from([
    OTelGraphqlLink(),
    _EchoLink(),
  ]);

  // 3. Execute an operation as usual. One span per operation:
  //    name `query GetUser`, attributes graphql.operation.type /
  //    graphql.operation.name. Variables are never captured.
  final request = Request(
    operation: Operation(
      document: parseString('query GetUser { user { id name } }'),
      operationName: 'GetUser',
    ),
  );

  await for (final response in link.request(request)) {
    print('data: ${response.data}');
  }

  await OTel.shutdown();
}

/// Stand-in terminating link so the example runs offline.
class _EchoLink extends Link {
  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    yield const Response(
      data: <String, dynamic>{
        'user': <String, dynamic>{'id': '1', 'name': 'Ada'},
      },
      response: <String, dynamic>{},
    );
  }
}
