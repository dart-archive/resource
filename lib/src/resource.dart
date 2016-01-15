// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:async" show Future, Stream;
import "dart:convert" show Encoding;
import "dart:isolate" show Isolate;
import "loader.dart";

/// A resource that can be read into the program.
///
/// A resource is data that can be located using a URI and read into
/// the program at runtime.
/// The URI may use the `package` scheme to read resources provided
/// along with package sources.
abstract class Resource {
  /// Creates a resource object with the given [uri] as location.
  ///
  /// The [uri] must be either a [Uri] or a string containing a valid URI.
  /// If the string is not a valid URI, using any of the functions on
  /// the resource object will fail.
  ///
  /// The URI may be relative, in which case it will be resolved
  /// against [Uri.base] before being used.
  ///
  /// The URI may use the `package` scheme, which is always supported.
  /// Other schemes may also be supported where possible.
  ///
  /// If [loader] is provided, it is used to load absolute non-package URIs.
  /// Package: URIs are resolved to a non-package URI before being loaded, so
  /// the loader doesn't have to support package: URIs, nor does it need to
  /// support relative URI references.
  /// If [loader] is omitted, a default implementation is used which supports
  /// as many of `http`, `https`, `file` and `data` as are available on the
  /// current platform.
  const factory Resource(uri, {ResourceLoader loader}) = _Resource;

  /// The location URI of this resource.
  ///
  /// This is a [Uri] of the `uri` parameter given to the constructor.
  /// If the parameter was a string that did not contain a valid URI,
  /// reading `uri` will fail.
  Uri get uri;

  /// Reads the resource content as a stream of bytes.
  Stream<List<int>> openRead();

  /// Reads the resource content as a single list of bytes.
  Future<List<int>> readAsBytes();

  /// Reads the resource content as a string.
  ///
  /// The content is decoded into a string using an [Encoding].
  /// If no other encoding is provided, it defaults to UTF-8.
  Future<String> readAsString({Encoding encoding});
}

class _Resource implements Resource {
  /// Loading strategy for the resource.
  final ResourceLoader _loader;

  /// The URI of the resource.
  final _uri;

  const _Resource(uri, {ResourceLoader loader})
      : _uri = uri, _loader = (loader != null) ? loader : const DefaultLoader();
  // TODO: Make this `loader ?? const DefaultLoader()` when ?? is const.

  Uri get uri => (_uri is String) ? Uri.parse(_uri) : (_uri as Uri);

  Stream<List<int>> openRead() async* {
    Uri uri = await _resolvedUri;
    yield* _loader.openRead(uri);
  }

  Future<List<int>> readAsBytes() async {
    Uri uri = await _resolvedUri;
    return _loader.readAsBytes(uri);
  }

  Future<String> readAsString({Encoding encoding}) async {
    Uri uri = await _resolvedUri;
    return _loader.readAsString(uri, encoding: encoding);
  }

  Future<Uri> get _resolvedUri => resolveUri(uri);
}
