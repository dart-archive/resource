// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A [Resource] is data that can be loaded into a Dart program.
///
/// This library provides an implementation of [Resource] and a
/// [PackageResolver] that controls how package: URIs are converted to
/// URIs that can be loaded.
library resource;

export "src/resource.dart" show Resource, PackageResolver;
