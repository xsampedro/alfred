import 'dart:async';
import 'dart:io';

class TypeHandler<T> {
  TypeHandler(this.handler);

  FutureOr Function(HttpRequest req, HttpResponse res, T value) handler;

  bool shouldHandle(dynamic item) => item is T;
}
