// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// dart:io based strategy for loading resources.

import "dart:io" show File, HttpClient, HttpClientRequest, HttpClientResponse;
import "dart:async" show Future, Stream;
import "dart:convert" show Encoding, UTF8;
import "package:typed_data/typed_buffers.dart" show Uint8Buffer;

Stream<List<int>> readAsStream(Uri uri) async* {
  if (uri.scheme == "file") {
    yield* new File.fromUri(uri).openRead();
    return;
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    HttpClientResponse response = await _httpGet(uri);
    yield* response;
    return;
  }
  throw new UnsupportedError("Unsupported scheme: $uri");
}

Future<List<int>> readAsBytes(Uri uri) async {
  if (uri.scheme == "file") {
    return new File.fromUri(uri).readAsBytes();
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    HttpClientResponse response = await _httpGet(uri);
    Uint8Buffer buffer = new Uint8Buffer();
    await for (var bytes in response) {
      buffer.addAll(bytes);
    }
    return buffer.toList();
  }
  throw new UnsupportedError("Unsupported scheme: $uri");
}

Future<String> readAsString(Uri uri, Encoding encoding) async {
  if (encoding == null) encoding = UTF8;
  if (uri.scheme == "file") {
    return new File.fromUri(uri).readAsString(encoding: encoding);
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    HttpClientResponse response = await _httpGet(uri);
    Uint8Buffer buffer = new Uint8Buffer();
    await for (var bytes in response) {
      buffer.addAll(bytes);
    }
    new String.fromCharCodes(buffer.toList());
  }
  throw new UnsupportedError("Unsupported scheme: $uri");
}

Future<HttpClientResponse> _httpGet(Uri uri) async {
  HttpClientRequest request = await new HttpClient().getUrl(uri);
  return await request.close();
}
