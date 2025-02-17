# Alfred

A performant, expressjs like server framework thats easy to use and has all the bits in one place.

[![Build Status](https://travis-ci.org/rknell/alfred.svg?branch=master)](https://travis-ci.org/rknell/alfred)

Quickstart:

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.get('/example', (req, res) => 'Hello world');

  await app.listen();
}
```

# Index
- [Core principles](#core-principles)
- [Usage overview](#usage-overview)
    - [Quick start guide](#quick-start-guide)
- [Routing & incoming requests](#routing--incoming-requests)
    - [Route params](#route-params)
    - [Query string variables](#query-string-variables)
    - [Body parsing](#body-parsing)
    - [File uploads](#file-uploads)
- [Middleware](#middleware)
    - [No 'next'?](#what-no-next-how-do-i-even)
    - [CORS](#cors)
- [Responses](#responses)
    - [Custom type handlers](#custom-type-handlers)
    - [Static Files](#static-files)
    - [File downloads](#file-downloads)
- [Error handling](#error-handling)
    - [404 Handling](#404-handling)
- [Databases](#but-what-about-mongo-or-postgres-or-databse-x)
- [What I want to do isn't listed](#what-i-want-to-do-isnt-listed)
- [Websockets](#websockets)
- [Logging](#logging)
    - [Print routes](#print-routes)
- [Multi threading & isolates](#multi-threading-and-isolates)
- [Contributions](#contributions)

## Core principles
- A minimum of dependencies,
- A minimum of code and sticking close to dart core libraries - easy to maintain!
- Ease of use
- Predictable, well established semantics
- 90%+ of everything you need all ready to go

[Read about the background behind the project or why its different to shelf](documentation/background.md)

## Usage overview

If you have ever used expressjs before you should be right at home:

```dart
import 'dart:io';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.get('/text', (req, res) => 'Text response');

  app.get('/json', (req, res) => {'json_response': true});

  app.get('/jsonExpressStyle', (req, res) {
    res.json({'type': 'traditional_json_response'});
  });

  app.get('/file', (req, res) => File('test/files/image.jpg'));

  app.get('/html', (req, res) {
    res.headers.contentType = ContentType.html;
    return '<html><body><h1>Test HTML</h1></body></html>';
  });

  await app.listen(6565); //Listening on port 6565
}
```

It should do pretty much what you expect. Handling bodies though do need an "await":

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.post('/post-route', (req, res) async {
    final body = await req.body; //JSON body
    body != null; //true
  });

  await app.listen(); //Listening on port 3000
}
```

Internally dart provides a body parser, so no extra dependencies there.

The big difference you will see is the option to not call `res.send` or `res.json` etc - although you still can.
Each route accepts a Future as response. Currently you can pass back the following and it will be sent appropriately:

| Return Dart Type | Returning REST type |
| ----------------- | ------------------ |
| `List<dynamic>` | JSON |
| `Map<String, Object?>` | JSON |
| Serializable object (Object.toJSON or Object.toJson) * see note | JSON |
| `String` | Plain Text |
| `Stream<List<int>>` | Binary |
| `List<int>` | Binary |
| `File` |  Binary, with mime type inferred by extension |
| `Directory` | Serves static files |

\* If your object has a "toJSON" or "toJson" function, alfred will run it, and then return the result

If you want to return HTML, just set the content type to HTML like this:

```dart
import 'dart:io';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.get('/html', (req, res) {
    res.headers.contentType = ContentType.html;
    return '<html><body><h1>Title!</h1></body></html>';
  });

  await app.listen(); //Listening on port 3000
}
```

If you want to return a different type and have it handled automatically, you can extend Alfred with
[custom type handlers](#custom-type-handlers).

### Quick start guide

If its all a bit overwhelming @iapicca put together a quick start guide which goes into a little 
more detail: https://medium.com/@iapicca/alfred-an-express-like-server-framework-written-in-dart-1661e8963db9

## Routing & incoming requests

Routing follows a similar pattern to the more basic ExpressJS routes. While there is some regex
matching, mostly just stick with the route name and param syntax from Express:

"/path/to/:id/property" etc

So for example:

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();
  app.all('/example/:id/:name', (req, res) {
    req.params['id'] != null;
    req.params['name'] != null;
  });
  await app.listen();
}
```

You can also use a wildcard for a route, and provided another route hasn't already resolved the
response it will be hit. So for example if you want to authenticate a whole section of an api youc 
can do this:

```dart
import 'dart:async';
import 'dart:io';

import 'package:alfred/alfred.dart';

FutureOr _authenticationMiddleware(HttpRequest req, HttpResponse res) async {
  res.statusCode = 401;
  await res.close();
}

void main() async {
  final app = Alfred();

  app.all('/resource*', (req, res) => _authenticationMiddleware);

  app.get('/resource', (req, res) {}); //Will not be hit
  app.post('/resource', (req, res) {}); //Will not be hit
  app.post('/resource/1', (req, res) {}); //Will not be hit

  await app.listen();
}
```

### Route params

You can access any params for routes from the `req.params` object as below:

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();
  app.all('/example/:id/:name', (req, res) {
    req.params['id'] != null;
    req.params['name'] != null;
  });
  await app.listen();
}
```

### Query string variables

Querystring variables are exposed `req.uri.queryParameters` object in the request as below:

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.post('/route', (req, res) async {
    /// Handle /route?qsvar=true
    final result = req.uri.queryParameters['qsvar'];
    result == 'true'; //true
  });

  await app.listen(); //Listening on port 3000
}
```

### Body parsing

To access the body, simply call `await req.body`.

Alfred will interpret the body type from the content type headers and parse it appropriately. It handles url encoded, multipart & json bodies out of the box.

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.post('/post-route', (req, res) async {
    final body = await req.body; //JSON body
    body != null; //true
  });

  await app.listen(); //Listening on port 3000
}
```

### File uploads

To upload a file the body parser will handle exposing the data you need. Its actually pretty easy
just give it a go and set a breakpoint to see what the body parser spits back.

A working example of file uploads is below to get you started:

```dart
import 'dart:io';

import 'package:alfred/alfred.dart';

final _uploadDirectory = Directory('uploadedFiles');

Future<void> main() async {
  final app = Alfred();

  app.get('/files/*', (req, res) => _uploadDirectory);

  /// Example of handling a multipart/form-data file upload
  app.post(
      '/upload',
      (req, res) => (HttpRequest req, HttpResponse res) async {
            final body = await req.bodyAsJsonMap;

            // Create the upload directory if it doesn't exist
            if (await _uploadDirectory.exists() == false) {
              await _uploadDirectory.create();
            }

            // Get the uploaded file content
            final uploadedFile = (body['file'] as HttpBodyFileUpload);
            var fileBytes = (uploadedFile.content as List<int>);

            // Create the local file name and save the file
            await File('${_uploadDirectory.absolute}/${uploadedFile.filename}')
                .writeAsBytes(fileBytes);

            /// Return the path to the user
            ///
            /// The path is served from the /files route above
            return ({
              'path':
                  'https://${req.headers.host ?? ''}/files/${uploadedFile.filename}'
            });
          });

  await app.listen();
}
```

## Middleware

You can specify a middleware for all routes by using wildcards:

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();
  app.all('*', (req, res) {
    // Perform action
    req.headers.add('x-custom-header', "Alfred isn't bad");

    /// No need to call next as we don't send a response.
    /// Alfred will find the next matching route
  });

  app.get('/otherFunction', (req, res) {
    //Action performed next
    return {'message': 'complete'};
  });

  await app.listen();
}
```

Middleware declared this way will be executed in the order its added to the app.

You can also add middleware to a route, this is great to enforce authentication etc on an endpoint:

```dart
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
```

### What? No 'next'? how do I even?  
OK, so the rules are simple. If a middleware resolves a http request, no future middleware gets executed.

So if you return an object from the middleware, you are preventing future middleware from executing.

If you return null it will yield to the next middleware or route.

** returning null is the equivalent of 'next' **

### CORS

There is a cors middleware supplied for your convenience. Its also a great example of how to write a middleware for Alfred

```dart
import 'package:alfred/alfred.dart';
import 'package:alfred/src/middleware/cors.dart';

void main() async {
  final app = Alfred();

  // Warning: defaults to origin "*"
  app.all('*', cors(origin: 'myorigin.com'));

  await app.listen();
}
```

## Responses

Alfred is super easy, generally you just return JSON, a file, a String or a Binary stream and you are all good.

The big difference from express is you will see is the option to not call `res.send` or `res.json` etc - although you still can.
Each route accepts a Future as response. Currently you can pass back the following and it will be sent appropriately:

- `List<dynamic>` - JSON
- `Map<String, Object?>` - JSON
- `String` - Plain text
- `Stream<List<int>>` - Binary
- `List<int>` - Binary
- `File` - Binary, with mime type inferred by extension
- `Directory` - Serves static files

Each type listed above has a `Type Handler` build in. [You can create your own custom type handlers](#custom-type-handlers)

### Custom type handlers
Alfred has a pretty cool mechanism thanks to Dart's type system to automatically resolve a response
based on the returned type from a route. These are called `Type Handlers`.

If you want to create custom type handlers, just add them to the type handler
array in the app object. This is a bit advanced, and I expect it would be more
for devs wanting to extend Alfred:

```dart
import 'package:alfred/alfred.dart';

class Chicken {
  String get response => 'I am a chicken';
}

void main() {
  final app = Alfred();

  app.typeHandlers.add(TypeHandler<Chicken>((req, res, dynamic val) async {
    res.write((val as Chicken).response);
    await res.close();
  }));

  /// The app will now return the Chicken.response if you return one from a route

  app.get('/kfc', (req, res) => Chicken()); //I am a chicken;

  app.listen(); //Listening on 3000
}
```

### Static Files, uploads and deleting

This one is super easy - just pass in a public path and a dart Directory object and Alfred does
the rest.

```dart
import 'dart:io';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  /// Note the wildcard (*) this is very important!!
  app.get('/public/*', (req, res) => Directory('test/files'));

  await app.listen();
}
```

You can also pass in a directory and a POST or PUT command and upload files to a local directory if 
you are using multipart/form encoding. Simply supply the field as `file`:

```dart
import 'dart:io';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.post('/public', (req, res) => Directory('test/files'));

  await app.listen();
}
```

If you want to delete a file?

```dart
import 'dart:async';
import 'dart:io';

import 'package:alfred/alfred.dart';

FutureOr isAuthenticatedMiddleware(HttpRequest req, HttpResponse res) {
  if (req.headers.value('Authorization') != 'MYAPIKEY') {
    throw AlfredException(
        401, {'error': 'You are not authorized to perform this operation'});
  }
}

void main() async {
  final app = Alfred();

  /// Note the wildcard (*) this is very important!!
  ///
  /// You almost certainly want to protect this endpoint with some middleware
  /// to authenticate a user.
  app.delete('/public/*', (req, res) => Directory('test/files'),
      middleware: [isAuthenticatedMiddleware]);

  await app.listen();
}
```

Security? Build in a middleware function to authenticate a user etc. 

### File downloads

As mentioned above - if you want to return a file, simply return it from the route callback.
However the browser will probably try to render it in browser, and not download it.

You can just set the right headers, but there is a handy little helper that will do it all for you.

See `res.setDownload` below.

```dart
import 'dart:io';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.get('/image/download', (req, res) {
    res.setDownload(filename: 'image.jpg');
    return File('test/files/image.jpg');
  });

  await app.listen(); //Listening on port 3000
}
```

## Error handling

You can either set the status code on the response object yourself and send the data manually, or
you can do this from any route:

app.get("/",(req, res) => throw AlfredException(400, {"message": "invalid request"}));

If any of the routes bubble an unhandled error, it will catch it and throw a 500 error.

If you want to handle the logic when a 500 error is thrown, you can add a custom handler when you
instantiate the app. For example:

```dart
import 'dart:async';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred(onInternalError: errorHandler);
  await app.listen();
  app.get('/throwserror', (req, res) => throw Exception('generic exception'));
}

FutureOr errorHandler(HttpRequest req, HttpResponse res) {
  res.statusCode = 500;
  return {'message': 'error not handled'};
}
```

### 404 Handling

404 Handling works the same as 500 error handling (or uncaught error handling). There is a default
behaviour, but if you want to override it, simply handle it in the app declaration.

```dart
import 'dart:async';
import 'dart:io';

import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred(onNotFound: missingHandler);
  await app.listen();
}

FutureOr missingHandler(HttpRequest req, HttpResponse res) {
  res.statusCode = 404;
  return {'message': 'not found'};
}
```

## But what about Mongo or Postgres or <Database x>?

The other two systems that inspired this project to be kicked off - Aqueduct and Angel - both had
some sort of database integration built in.

**You do not need this.**

Access the dart drivers for the database system you want directly, they all use them behind the scenes:

- Mongo - https://pub.dev/packages/mongo_dart
- Postgres - https://pub.dev/packages/postgres
- SQLLite -  https://pub.dev/packages/sqlite3

You will be fine. I have used them this way and they work.

I have rolled my own classes that act as a sort of ORM, especially around Mongo. Its suprisingly effective
and doesn't rely on much code.

## What I want to do isn't listed

While there are bunch of helpers built in - you have direct access to the low level apis available
from the dart:io package. All helpers are just extension methods to:

- HttpRequest: https://api.dart.dev/stable/2.10.5/dart-io/HttpRequest-class.html
- HttpResponse: https://api.dart.dev/stable/2.10.5/dart-io/HttpResponse-class.html

So you can compose and write any content you can imagine there. If there is something you wan't to do
that isn't expressly listed by the library, you will be able to do it with a minimum of research into
underlying libraries. A core part of the architecture is to not build you into a wall.

## Websockets

Alfred supports websockets too!

There is a quick chat client in the examples

```dart
import 'dart:async';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:alfred/src/type_handlers/websocket_type_handler.dart';

Future<void> main() async {
  final app = Alfred();

  // Path to this Dart file
  var dir = File(Platform.script.path).parent.path;

  // Deliver web client for chat
  app.get('/', (req, res) => File('$dir/chat-client.html'));

  // Track connected clients
  var users = <WebSocket>[];

  // WebSocket chat relay implementation
  app.get('/ws', (req, res) {
    return WebSocketSession(
      onOpen: (ws) {
        users.add(ws);
        users
            .where((user) => user != ws)
            .forEach((user) => user.send('A new user joined the chat.'));
      },
      onClose: (ws) {
        users.remove(ws);
        users.forEach((user) => user.send('A user has left.'));
      },
      onMessage: (ws, dynamic data) async {
        users.forEach((user) => user.send(data));
      },
    );
  });

  final server = await app.listen();

  print('Listening on ${server.port}');
}
```

## Logging

For more details on logging [click here](documentation/logging.md).

### Print routes

Want to quickly print out the registered routes? (recommended when you fire up the server) 
call Alfred.printRoutes ie:

```dart
import 'package:alfred/alfred.dart';

void main() async {
  final app = Alfred();

  app.get('/html', (req, res) {});

  app.printRoutes(); //Will print the routes to the console

  await app.listen();
}
```

## Multi threading and isolates

You can use the app in multithreaded mode. When spawning this way, requests are evenly distributed
amongst the various isolates. Alfred is not particularly prescriptive about how you manage the isolates
just that "it works" when you fire up multiples.

```dart
import 'dart:isolate';

import 'package:alfred/alfred.dart';

Future<void> main() async {
  // Fire up 5 isolates
  for (var i = 0; i < 5; i++) {
    unawaited(Isolate.spawn(startInstance, ''));
  }
  // Start listening on this isolate also
  startInstance(null);
}

/// The start function needs to be top level or static. You probably want to
/// run your entire app in an isolate so you don't run into trouble sharing DB
/// connections etc. However you can engineer this however you like.
///
void startInstance(dynamic message) async {
  final app = Alfred();

  app.all('/example', (req, res) => 'Hello world');

  await app.listen();
}

/// Simple function to prevent linting errors, can be ignored
void unawaited(Future future) {}
```

# Deployment

There are many ways to skin this cat, you can upload the source code to a VPS yourself, build a binary locally and upload it to a server somewhere, but a fairly elegant way to accomplish a production level deployment is to containerize an AOT build of the server and run it on a PAAS.

Lucky there is a tutorial for that!
https://ryan-knell.medium.com/build-and-deploy-a-dart-server-using-alfred-docker-and-google-cloud-run-from-start-to-finish-d5066e3ab3c6

# Contributions

PRs are welcome and encouraged! This is a community project and as long as the PR keeps within the key principles listed it will probably be accepted. If you have an improvement you would like to to add but are not sure just reach out in the issues section.

Before you submit your code, you can run the `ci_checks.sh` shell script that will do many of the tests the CI suite will perform.