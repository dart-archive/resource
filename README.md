# Resource

Reading data from package contents and files.

A resource is data that can be read into a Dart program at runtime.
A resource is identified by a URI. It can be loaded as bytes or data.
The resource URI may be a package: URI.

Example:

```
import 'package:resource/resource.dart' show Resource;
import 'dart:convert' show UTF8;

main() async {
  var resource = new Resource("package:foo/foo_data.txt");
  var string = await resource.readAsString(UTF8);
  print(string);
}
```

## Learning more

Please check out the [API docs](https://www.dartdocs.org/documentation/resource/latest).

## Features and bugs

The current version of `resource.dart` depends on the `dart:io` library,
and doesn't work in the browser.
Use `package:resource/browser_resource.dart` in the browser until
further notice.

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dart-lang/resource/issues
