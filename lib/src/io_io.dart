// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:async" show Future, Stream;
import "dart:convert" show Encoding, latin1, utf8;
import "dart:io"
    show
        File,
        HttpStatus,
        HttpClient,
        HttpClientResponse,
        HttpClientRequest,
        HttpException,
        HttpHeaders;

import "package:typed_data/typed_buffers.dart" show Uint8Buffer;

/// Read the bytes of a URI as a stream of bytes.
Stream<List<int>> readAsStream(Uri uri) async* {
  if (uri.scheme == "file") {
    yield* File.fromUri(uri).openRead();
    return;
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    var response = await _httpGetBytes(uri);
    _throwIfFailed(response, uri);
    yield* response;
    return;
  }
  if (uri.scheme == "data") {
    yield uri.data.contentAsBytes();
    return;
  }
  throw UnsupportedError("Unsupported scheme: $uri");
}

/// Read the bytes of a URI as a list of bytes.
Future<List<int>> readAsBytes(Uri uri) async {
  if (uri.scheme == "file") {
    return File.fromUri(uri).readAsBytes();
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    var response = await _httpGetBytes(uri);
    _throwIfFailed(response, uri);
    var length = response.contentLength;
    if (length < 0) length = 0;
    // Create empty buffer with capacity matching contentLength.
    var buffer = Uint8Buffer(length)..length = 0;
    await for (var bytes in response) {
      buffer.addAll(bytes);
    }
    return buffer.toList();
  }
  if (uri.scheme == "data") {
    return uri.data.contentAsBytes();
  }
  throw UnsupportedError("Unsupported scheme: $uri");
}

/// Read the bytes of a URI as a string.
Future<String> readAsString(Uri uri, Encoding encoding) async {
  if (uri.scheme == "file") {
    encoding ??= utf8;
    return File.fromUri(uri).readAsString(encoding: encoding);
  }
  if (uri.scheme == "http" || uri.scheme == "https") {
    var request = await HttpClient().getUrl(uri);
    // Prefer text/plain, text/* if possible, otherwise take whatever is there.
    request.headers.set(HttpHeaders.acceptHeader, "text/plain, text/*, */*");
    if (encoding != null) {
      request.headers.set(HttpHeaders.acceptCharsetHeader, encoding.name);
    }
    var response = await request.close();
    _throwIfFailed(response, uri);
    encoding ??= Encoding.getByName(response.headers.contentType?.charset);
    if (encoding == null || encoding == latin1) {
      // Default to LATIN-1 if no encoding found.
      // Special case LATIN-1 since it is common and doesn't need decoding.
      var length = response.contentLength;
      if (length < 0) length = 0;
      // Create empty buffer with capacity matching contentLength.
      var buffer = Uint8Buffer(length)..length = 0;
      await for (var bytes in response) {
        buffer.addAll(bytes);
      }
      var byteList = buffer.buffer.asUint8List(0, buffer.length);
      return String.fromCharCodes(byteList);
    }
    return response.cast<List<int>>().transform(encoding.decoder).join();
  }
  if (uri.scheme == "data") {
    return uri.data.contentAsString(encoding: encoding);
  }
  throw UnsupportedError("Unsupported scheme: $uri");
}

HttpClient _sharedHttpClient = HttpClient()..maxConnectionsPerHost = 6;

Future<HttpClientResponse> _httpGetBytes(Uri uri) async {
  // ignore: omit_local_variable_types
  HttpClientRequest request = await _sharedHttpClient.getUrl(uri);
  request.headers
      .set(HttpHeaders.acceptHeader, "application/octet-stream, */*");
  return request.close();
}

void _throwIfFailed(HttpClientResponse response, Uri uri) {
  var statusCode = response.statusCode;
  if (statusCode < HttpStatus.ok || statusCode > HttpStatus.noContent) {
    throw HttpException(response.reasonPhrase, uri: uri);
  }
}
