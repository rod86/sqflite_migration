import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_migration/src/exceptions/sql_migration_exception.dart';
import 'package:sqflite_migration/src/database_migration_service.dart';

import 'setup/test_helpers.dart';

void main() {
  group('DatabaseMigrationServiceTest -', () {
    setUp(() {
      getAndRegisterSharedPreferencesMock();
      getAndRegisterAssetReaderMock();
    });
    // tearDown(() => locator<SharedPreferencesService>());

    group('runMigration -', () {
      test('When called should get the databaseVersion from sharedPreferences',
          () async {
        var sharedPreferences = getAndRegisterSharedPreferencesMock();
        var migrationHelper = DatabaseMigrationService();
        await migrationHelper.runMigration(null, migrationFiles: []);
        verify(sharedPreferences.databaseVersion);
      });

      test(
          'When asset reader returns null for file, should throw Sql Migration',
          () async {
        getAndRegisterAssetReaderMock(fileContent: null);
        var migrationHelper = DatabaseMigrationService();

        expect(
          () async => await migrationHelper
              .runMigration(null, migrationFiles: ['1_migration']),
          throwsA(predicate((exception) => exception is SqlMigrationException)),
        );
      });

      test(
          'When 1_migration.sql passed to constructor, should get content for 1_migration.sql from asset reader',
          () async {
        var assetReader = getAndRegisterAssetReaderMock();
        var migrationHelper = DatabaseMigrationService();
        await migrationHelper
            .runMigration(null, migrationFiles: ['1_migration.sql']);
        verify(assetReader.readFileFromBundle('1_migration.sql'));
      });

      test(
          'When 1_migration.sql passed to constructor and database version is 1, should not get 1_migration.sql from asset reader',
          () async {
        getAndRegisterSharedPreferencesMock(databaseVersion: 1);
        var assetReader = getAndRegisterAssetReaderMock();
        var migrationHelper = DatabaseMigrationService();
        await migrationHelper
            .runMigration(null, migrationFiles: ['1_migration.sql']);
        verifyNever(assetReader.readFileFromBundle('1_migration.sql'));
      });

      test(
          'When asset reader returns sql, should apply all queries to database as a raw query',
          () async {
        var database = getDatabaseMock();
        getAndRegisterAssetReaderMock(fileContent: '''
            Add Table orders (
              id INT,
              token TEXT,
            );
    
            Add Table types (
              name TEXT,
              selected INT,
            );
          ''');
        var migrationHelper = DatabaseMigrationService();
        await migrationHelper
            .runMigration(database, migrationFiles: ['1_migration.sql']);
        verify(database.rawQuery('Add Table orders (id INT,token TEXT,)'));
        verify(database.rawQuery('Add Table types (name TEXT,selected INT,)'));
      });

      test(
          'When migration for a file is complete, should set the version equal to the number the file starts with',
          () async {
        var database = getDatabaseMock();
        var sharedPreferences = getAndRegisterSharedPreferencesMock();
        getAndRegisterAssetReaderMock(fileContent: '''
            Add Table orders (
              id INT,
              token TEXT,
            );
    
            Add Table types (
              name TEXT,
              selected INT,
            );
          ''');
        var migrationHelper = DatabaseMigrationService();
        await migrationHelper
            .runMigration(database, migrationFiles: ['1_migration.sql']);
        verify(sharedPreferences.databaseVersion = 1);
      });
    });

    group('getMigrationQueriesFromScript -', () {
      test(
          'When given a string on 1 line with no semi colon should return the query',
          () {
        var content = '''This is string''';
        var migrationHelper = DatabaseMigrationService();
        var migrationQueries =
            migrationHelper.getMigrationQueriesFromScript(content);
        expect(migrationQueries.length, 1);
      });

      test('When given a string with 2 queries should return 2 queries', () {
        var content = '''
            Add Table orders (
              id INT,
              token TEXT,
            );
    
            Add table types (
              name TEXT,
              selected INT,
            );
            ''';
        var migrationHelper = DatabaseMigrationService();
        var migrationQueries =
            migrationHelper.getMigrationQueriesFromScript(content);
        expect(migrationQueries.length, 2);
      });

      test(
          'When given a string with 2 queries should return each query as 1 line',
          () {
        var content = '''
            Add Table orders (
              id INT,
              token TEXT,
            );
    
            Add table types (
              name TEXT,
              selected INT,
            );
            ''';
        var migrationHelper = DatabaseMigrationService();
        var migrationQueries =
            migrationHelper.getMigrationQueriesFromScript(content);
        expect(migrationQueries.first, 'Add Table orders (id INT,token TEXT,)');
      });
    });
  });
}
