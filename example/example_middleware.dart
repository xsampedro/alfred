import 'dart:async';
import 'dart:io';

import 'package:alfred/alfred.dart';

FutureOr exampleMiddlware(HttpRequest req, HttpResponse res) {
  // Do work
  if (req.headers.value('Authorization') != 'apikey') {
    throw AlfredException(401, {'message': 'authentication failed'});
  }
}

void main() async {
  final app = Alfred();
  app.all('/example/:id/:name', (req, res) {}, middleware: [exampleMiddlware]);

  await app.listen(); //Listening on port 3000
}
