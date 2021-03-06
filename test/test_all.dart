// Copyright (c) 2013, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


import 'publisher_test.dart' as publisher_test;
import 'mongo_provider_test.dart' as mongo_provider_test;
import 'client_test.dart' as client_test;
import 'id_generator_test.dart' as id_generator_test;
import 'exception_test.dart' as exception_test;
import 'collection_modification_test.dart' as collection_modification_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import 'package:logging/logging.dart';

final Logger logger = new Logger('clean_sync');

main() {
  run(new VMConfiguration());
}

run(configuration) {
  unittestConfiguration = configuration;
  hierarchicalLoggingEnabled = true;
  logger.level = Level.WARNING;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  mongo_provider_test.main();
  publisher_test.main();
  client_test.main();
  id_generator_test.main();
  exception_test.main();
  collection_modification_test.run();
}
