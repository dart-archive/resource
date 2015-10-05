// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library resoure.resource;

import "dart:async" show Future, Stream;
import "dart:convert" show Encoding;
import "dart:isolate" show Isolate;
import "package_resolver.dart";
import "io.dart" as io;  // Loading strategy. TODO: Be configuration dependent.

/// A strategy for resolving package URIs
abstract class PackageResolver {
  /// Cache of the current resolver, accessible directly after it has first
  /// been found asynchronously.
  static PackageResolver _current;

  /// The package resolution strategy used by the current isolate.
  static final Future<PackageResolver> current = _findIsolateResolution();

  PackageResolver();

  /// Creates a resolver using a map from package name to package location.
  factory PackageResolver.fromMap(Map<String, Uri> packages) = MapResolver;

  /// Creates a resolver using a package root.
  factory PackageResolver.fromRoot(Uri packageRoot) = RootResolver;

  /// Resolves a package URI to its location.
  ///
  /// If [uri] does not have `package` as scheme, it is returned again.
  /// Otherwise the package name is looked up, and if found, a location
  /// for the package file is returned.
  Future<Uri> resolve(Uri uri);

  /// Returns a [Resource] for the [uri] as resolved by this resolver.
  Resource resource(Uri uri) {
    return new _UriResource(this, uri);
  }

  /// Finds the way the current isolate resolves package URIs.
  ///
  /// Is only called once, and when it has been called, the [_current]
  /// resolver is initialized, so [UriResource] will be initialized
  /// with the resolver directly.
  static Future<PackageResolver> _findIsolateResolution() async {
    var pair = await Future.wait([Isolate.packageRoot, Isolate.packageMap]);
    Uri root = pair[0];
    if (root != null) {
      _current = new RootResolver(root);
    } else {
      Map<String, Uri> map = pair[1];
      _current = new MapResolver(map);
    }
    return _current;
  }
}

/// A resource that can be read into the program.
///
/// A resource is data that can be located using a URI and read into
/// the program at runtime.
/// The URI may use the `package` scheme to read resources provided
/// along with package sources.
abstract class Resource {
  /// Creates a resource object with the given [uri] as location.
  ///
  /// The `uri` is a string containing a valid URI.
  /// If the string is not a valid URI, using any of the functions on
  /// the resource object will fail.
  ///
  /// The URI may be relative, in which case it will be resolved
  /// against [Uri.base] before being used.
  ///
  /// The URI may use the `package` scheme, which is always supported.
  /// Other schemes may also be supported where possible.
  const factory Resource(String uri) = _StringResource;

  /// Creates a resource object with the given [uri] as location.
  ///
  /// The URI may be relative, in which case it will be resolved
  /// against [Uri.base] before being used.
  ///
  /// The URI may use the `package` scheme, which is always supported.
  /// Other schemes may also be supported where possible.
  factory Resource.forUri(Uri uri) =>
      new _UriResource(PackageResolver._current, uri);

  /// The location `uri` of this resource.
  ///
  /// This is a [Uri] of the `uri` parameter given to the constructor.
  /// If the parameter was not a valid URI, reading `uri` may fail.
  Uri get uri;

  Stream<List<int>> openRead();

  Future<List<int>> readAsBytes();

  /// Read the resource content as a string.
  ///
  /// The content is decoded into a string using an [Encoding].
  /// If no other encoding is provided, it defaults to UTF-8.
  Future<String> readAsString({Encoding encoding});
}

class _StringResource implements Resource {
  final String _uri;

  const _StringResource(String uri) : _uri = uri;

  Uri get uri => Uri.parse(_uri);

  Stream<List<int>> openRead() {
    return new _UriResource(PackageResolver._current, uri).openRead();
  }
  Future<List<int>> readAsBytes() {
    return new _UriResource(PackageResolver._current, uri).readAsBytes();
  }
  Future<String> readAsString({Encoding encoding}) {
    return new _UriResource(PackageResolver._current, uri)
                   .readAsString(encoding: encoding);
  }
}

class _UriResource implements Resource {
  /// The strategy for resolving package: URIs.
  ///
  /// May be null intially. If so, the [PackageResolver.current] resolver is
  /// used (and cached for later use).
  PackageResolver _resolver;

  /// The URI of the resource.
  final Uri uri;

  _UriResource(this.resolver, Uri uri);

  Stream<List<int>> openRead() async* {
    Uri uri = await _resolve(this.uri);
    return io.readAsStream(uri);
  }

  Future<List<int>> readAsBytes() async {
    Uri uri = await _resolve(this.uri);
    return io.readAsBytes(uri);
  }

  Future<String> readAsString({Encoding encoding}) async {
    Uri uri = await _resolve(this.uri);
    return io.readAsString(uri, encoding);
  }

  static void _checkPackageUri(Uri uri) {
    if (uri.scheme != "package") {
      throw new ArgumentError.value(uri, "Not a package: URI");
    }
    if (uri.hasAuthority) {
      throw new ArgumentError.value(uri,
          "A package: URI must not have an authority part");
    }
    if (uri.path.isEmpty || uri.path.startsWith('/')) {
      throw new ArgumentError.value(uri,
          "A package: URI must have the form "
          "'package:packageName/packagePath'");
    }
    if (uri.hasQuery) {
      throw new ArgumentError.value(uri,
          "A package: URI must not have a query part");
    }
    if (uri.hasFragment) {
      throw new ArgumentError.value(uri,
          "A package: URI must not have a fragment part");
    }
  }

  Future<Uri> _resolve(Uri uri) async {
    if (uri.scheme != "package") {
      return Uri.base.resolveUri(uri);
    }
    _checkPackageUri(uri);
    _resolver ??= await PackageResolver._current;
    return _resolver.resolve(uri);
  }
}

/// A [PackageResolver] based on a packags map.
class MapResolver extends PackageResolver {
  Map<String, Uri> _mapping;

  MapResolver(this._mapping);

  Uri resolve(Uri uri) {
    if (uri.scheme != "package") return uri;
    var path = uri.path;
    int slashIndex = path.indexOf('/');
    if (slashIndex <= 0) {
      throw new ArgumentError.value(uri, "Invalid package URI");
    }
    int packageName = path.substring(0, slashIndex);
    var base = _mapping[packageName];
    if (base != null) {
      int packagePath = path.substring(slashIndex + 1);
      return base.resolveUri(new Uri(path: packagePath));
    }
    throw new UnsupportedError("No package named '$packageName' found");
  }
}

/// A [PackageResolver] based on a package root.
class RootResolver extends PackageResolver {
  Uri _root;
  RootResolver(this._root);

  Uri resolve(Uri uri) {
    if (uri.scheme != "package") return uri;
    return _root.resolve(uri.path);
  }
}
