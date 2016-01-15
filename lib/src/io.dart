// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// dart:io based strategy for loading resources.

import "dart:async" show Future, Stream;
import "dart:convert" show Encoding, LATIN1, UTF8;
import "dart:io" show
    File, HttpClient, HttpClientResponse, HttpClientRequest, HttpHeaders;
import "dart:typed_data" show Uint8List;
import "package:typed_data/typed_buffers.dart" show Uint8Buffer;

/// Read the bytes of a URI as a stream of bytes.
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
  if (uri.scheme == "data") {
    yield uri.data.contentAsBytes();
    return;
  }
  throw new UnsupportedError("Unsupported scheme: $uri");
}

/// Read the bytes of a URI as a list of bytes.
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
  if (uri.scheme == "data") {
    return uri.data.contentAsBytes();
  }
  throw new UnsupportedError("Unsupported scheme: $uri");
}

/// Read the bytes of a URI as a string.
Future<String> readAsString(Uri uri, Encoding encoding) async {
  if (uri.scheme == "file") {
    if (encoding == null) encoding = UTF8;
    return new File.fromUri(uri).readAsString(encoding: encoding);
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    HttpClientRequest request = await new HttpClient().getUrl(uri);
    // Prefer text/plain, text/* if possible, otherwise take whatever is there.
    request.headers.set(HttpHeaders.ACCEPT, "text/plain, text/*, */*");
    if (encoding != null) {
      request.headers.set(HttpHeaders.ACCEPT_CHARSET, encoding.name);
    }
    HttpClientResponse response = await request.close();
    encoding ??= Encoding.getByName(response.headers.contentType?.charset);
    if (encoding == null || encoding == LATIN1) {
      // Default to LATIN-1 if no encoding found.
      // Special case LATIN-1 since it is common and doesn't need decoding.
      int length = response.contentLength;
      if (length < 0) length = 0;
      Uint8Buffer buffer = new Uint8Buffer(length);
      await for (var bytes in response) {
        buffer.addAll(bytes);
      }
      var byteList = new Uint8List.view(buffer.buffer, 0, buffer.length);
      return new String.fromCharCodes(byteList);
    }
    return response.transform(encoding.decoder).join();
  }
  if (uri.scheme == "data") {
    return uri.data.contentAsString(encoding: encoding);
  }
  throw new UnsupportedError("Unsupported scheme: $uri");
}

Future<HttpClientResponse> _httpGet(Uri uri) async {
  HttpClientRequest request = await new HttpClient().getUrl(uri);
    request.headers.set(HttpHeaders.ACCEPT, "application/octet-stream, */*");
  return request.close();
}
