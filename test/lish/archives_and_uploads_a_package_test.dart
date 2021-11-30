// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.10

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:pub/src/exit_codes.dart' as exit_codes;
import 'package:pub/src/io.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import '../descriptor.dart' as d;
import '../test_pub.dart';
import 'utils.dart';

void main() {
  setUp(d.validPackage.create);

  test('archives and uploads a package', () async {
    await servePackages();
    await d.credentialsFile(globalPackageServer, 'access token').create();
    var pub = await startPublish(globalPackageServer);

    await confirmPublish(pub);
    handleUploadForm(globalPackageServer);
    handleUpload(globalPackageServer);

    globalPackageServer.expect('GET', '/create', (request) {
      return shelf.Response.ok(jsonEncode({
        'success': {'message': 'Package test_pkg 1.0.0 uploaded!'}
      }));
    });

    expect(pub.stdout, emits(startsWith('Uploading...')));
    expect(pub.stdout, emits('Package test_pkg 1.0.0 uploaded!'));
    await pub.shouldExit(exit_codes.SUCCESS);
  });

  test('publishes to hosted-url with path', () async {
    await servePackages();
    await d.tokensFile({
      'version': 1,
      'hosted': [
        {'url': globalPackageServer.url + '/sub/folder', 'env': 'TOKEN'},
      ]
    }).create();
    var pub = await startPublish(
      globalPackageServer,
      path: '/sub/folder',
      authMethod: 'token',
      environment: {'TOKEN': 'access token'},
    );

    await confirmPublish(pub);
    handleUploadForm(globalPackageServer, path: '/sub/folder');
    handleUpload(globalPackageServer);

    globalPackageServer.expect('GET', '/create', (request) {
      return shelf.Response.ok(jsonEncode({
        'success': {'message': 'Package test_pkg 1.0.0 uploaded!'}
      }));
    });

    expect(pub.stdout, emits(startsWith('Uploading...')));
    expect(pub.stdout, emits('Package test_pkg 1.0.0 uploaded!'));
    await pub.shouldExit(exit_codes.SUCCESS);
  });

  // This is a regression test for #1679. We create a submodule that's not
  // checked out to ensure that file listing doesn't choke on the empty
  // directory.
  test('with an empty Git submodule', () async {
    await d.git('empty').create();

    var repo = d.git(appPath);
    await repo.create();

    await repo.runGit(['submodule', 'add', '../empty', 'empty']);
    await repo.commit();

    deleteEntry(p.join(d.sandbox, appPath, 'empty'));
    await d.dir(p.join(appPath, 'empty')).create();

    await servePackages();
    await d.credentialsFile(globalPackageServer, 'access token').create();
    var pub = await startPublish(globalPackageServer);

    await confirmPublish(pub);
    handleUploadForm(globalPackageServer);
    handleUpload(globalPackageServer);

    globalPackageServer.expect('GET', '/create', (request) {
      return shelf.Response.ok(jsonEncode({
        'success': {'message': 'Package test_pkg 1.0.0 uploaded!'}
      }));
    });

    expect(pub.stdout, emits(startsWith('Uploading...')));
    expect(pub.stdout, emits('Package test_pkg 1.0.0 uploaded!'));
    await pub.shouldExit(exit_codes.SUCCESS);
  });

  // TODO(nweiz): Once a multipart/form-data parser in Dart exists, we should
  // test that "pub lish" chooses the correct files to publish.
}
