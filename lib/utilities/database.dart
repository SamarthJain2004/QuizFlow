import 'dart:convert';

import 'package:quizflow/models/answer.dart';
import 'package:quizflow/models/subset.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quizflow/models/voc.dart';
import 'package:quizflow/models/word.dart';

class DatabaseService {
  static const String databaseName = "quizflowDB.sqlite";
  static Database? db;

  static const databaseVersion = 3;
  List<String> tables = ["Vocs", "Words", "Answers", "Subsets"];

  static Future<Database> initializeDb() async {
    final databasePath = (await getApplicationDocumentsDirectory()).path;
    final path = join(databasePath, databaseName);
    return db ??
        await openDatabase(
          path,
          version: databaseVersion,
          onCreate: (Database db, int version) async {
            await createTables(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await updateTables(db, oldVersion, newVersion);
          },
          onOpen: (db) async {
            await openDB(db);
          },
        );
  }

  static openDB(Database db) {
    db.rawQuery('SELECT * FROM sqlite_master ORDER BY name;').then((value) {
      print(value);
    });
  }

  static updateTables(Database db, int oldVersion, int newVersion) async {
    print(" DB Version : $newVersion");
    print(oldVersion);
    if (oldVersion < newVersion) {
      if (oldVersion < 2) {
        await db.execute("""
          CREATE TABLE Subsets(
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             "from" INTEGER,
             "to" INTEGER,
             vocId INTEGER
          )
        """);
      }

      if (oldVersion < 3) {
        await db.transaction((txn) async {
          // 1. Rename old Words table
          await txn.execute('ALTER TABLE Words RENAME TO Words_old');

          // 2. Create new Words table without `definition`
          await txn.execute("""
            CREATE TABLE Words(
      	       id INTEGER PRIMARY KEY AUTOINCREMENT,
      	       word TEXT,
      	       vocId INTEGER
            )
          """);

          // 3. Create new Answers table
          await txn.execute("""
    	    CREATE TABLE Answers(
      	       id INTEGER PRIMARY KEY AUTOINCREMENT,
      	       answer TEXT,
      	       wordId INTEGER,
      	       vocId INTEGER
    	    )
  	  """);

          // 4. Copy data from Words_old to Words (excluding definition)
          await txn.execute("""
    	    INSERT INTO Words (id, word, vocId)
    	    SELECT id, word, vocId FROM Words_old
  	  """);

          // 5. Copy definitions into Answers
          await txn.execute("""
            INSERT INTO Answers (answer, wordId, vocId)
    	    SELECT definition, id, vocId FROM Words_old
  	  """);

          // 6. Drop the old Words table
          await txn.execute('DROP TABLE Words_old');
        });
      }
    }
  }

  static Future<void> createTables(Database database) async {
    await database.execute("""
      CREATE TABLE Vocs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          description TEXT
      )
    """);

    await database.execute("""
      CREATE TABLE Words(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT,
          vocId INTEGER
      )
    """);

    await database.execute("""
      CREATE TABLE Answers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          answer TEXT,
	  wordId INTEGER,
          vocId INTEGER
      )
    """);

    await database.execute("""
      CREATE TABLE Subsets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          "from" INTEGER,
          "to" INTEGER,
          vocId INTEGER
      )
    """);
  }

  static Future<int> createVoc(Voc voc) async {
    print("CREATE");

    final db = await DatabaseService.initializeDb();

    final id = await db.insert('Vocs', voc.toMap());
    return id;
  }

  static Future<int> createWord(Word word) async {
    final db = await DatabaseService.initializeDb();

    final id = await db.insert('Words', word.toMap());
    return id;
  }

  static Future<int> createAnswer(Answer answer) async {
    final db = await DatabaseService.initializeDb();

    final id = await db.insert('Answers', answer.toMap());
    return id;
  }

  static Future<int> createSubset(Subset subset) async {
    final db = await DatabaseService.initializeDb();

    final id = await db.insert('Subsets', subset.toMap());
    return id;
  }

  static Future<List<Voc>> getVocs({String searchQuery = ""}) async {
    final db = await DatabaseService.initializeDb();

    List<Map<String, dynamic>> queryResult = await db.query(
      'Vocs',
      where: "title LIKE '%$searchQuery%'",
    );

    return queryResult.map((e) => Voc.fromMap(e)).toList();
  }

  static Future<List<Word>> getWords() async {
    final db = await DatabaseService.initializeDb();

    List<Map<String, dynamic>> queryResult = await db.query('Words');

    return queryResult.map((e) => Word.fromMap(e)).toList();
  }

  static Future<List<Word>> getSubsets() async {
    final db = await DatabaseService.initializeDb();

    List<Map<String, dynamic>> queryResult = await db.query('Subsets');

    return queryResult.map((e) => Word.fromMap(e)).toList();
  }

  static Future<List<Word>> getWordsFromVoc(int vocId) async {
    final db = await DatabaseService.initializeDb();

    List<Map<String, dynamic>> vocWords = await db.query(
      'Words',
      where: "vocId = $vocId",
    );

    return vocWords.map((e) => Word.fromMap(e)).toList();
  }

  static Future<List<Answer>> getAnswersFromWord(int wordId) async {
    final db = await DatabaseService.initializeDb();

    List<Map<String, dynamic>> wordAnswers = await db.query(
      'Answers',
      where: "wordId = $wordId",
    );

    return wordAnswers.map((e) => Answer.fromMap(e)).toList();
  }

  static Future<List<Subset>> getSubsetsFromVoc(int vocId) async {
    final db = await DatabaseService.initializeDb();

    List<Map<String, dynamic>> vocSubsets = await db.query(
      'Subsets',
      where: "vocId = $vocId",
    );

    return vocSubsets.map((e) => Subset.fromMap(e)).toList();
  }

  static Future<void> removeVoc(int vocId) async {
    final db = await DatabaseService.initializeDb();
    db.delete("Vocs", where: "id = $vocId");
    db.delete("Words", where: "vocId = $vocId");
  }

  static Future<void> removeWord(int wordId) async {
    final db = await DatabaseService.initializeDb();
    db.delete("Words", where: "id = $wordId");
  }

  static Future<void> removeSubset(int subsetId) async {
    final db = await DatabaseService.initializeDb();
    db.delete("Subsets", where: "id = $subsetId");
  }

  static Future<void> removeWordsFromVoc(int vocId) async {
    final db = await DatabaseService.initializeDb();
    db.delete("Words", where: "vocId = $vocId");
  }

  static Future<void> removeAnswersFromVoc(int vocId) async {
    final db = await DatabaseService.initializeDb();
    db.delete("Answers", where: "vocId = $vocId");
  }

  static Future<void> removeSubsetsFromVoc(int vocId) async {
    final db = await DatabaseService.initializeDb();
    db.delete("Subsets", where: "vocId = $vocId");
  }

  static Future<void> updateVoc(Voc voc) async {
    final db = await DatabaseService.initializeDb();
    db.update("Vocs", voc.toMap(), where: 'id = ?', whereArgs: [voc.id]);
  }

  static Future<void> updateWord(Word word) async {
    print("UPDATE");

    final db = await DatabaseService.initializeDb();

    db.update("Words", word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  static Future<void> updateSubset(Subset subset) async {
    print("UPDATE");

    final db = await DatabaseService.initializeDb();

    db.update(
      "Subsets",
      subset.toMap(),
      where: 'id = ?',
      whereArgs: [subset.id],
    );
  }

  static Future<String> exportVoc(Voc voc) async {
    List<Word> words = await getWordsFromVoc(voc.id!);
    List<Subset> subsets = await getSubsetsFromVoc(voc.id!);

    Map result = voc.toMap();

    List<Map<dynamic, dynamic>> wordsMap = [];

    for (Word word in words) {
      List<Answer> answers = await getAnswersFromWord(word.id!);
      Map<String, dynamic> wordMap = word.toMap();
      wordMap["answers"] = answers.map((e) => e.toMap()).toList();
      wordsMap.add(wordMap);
    }

    List<Map<dynamic, dynamic>> subsetsMap = subsets
        .map((e) => e.toMap())
        .toList();

    result["words"] = wordsMap;
    result["subsets"] = subsetsMap;
    return jsonEncode(result);
  }

  static Future importVoc(String backup) async {
    Map<String, dynamic> jsonData = jsonDecode(backup);
    Voc voc = Voc.fromMap(jsonData);
    int vocId = await createVoc(voc);

    List wordsMap = jsonData["words"];
    List subsetsMap = jsonData["subsets"];

    for (var i = 0; i < wordsMap.length; i++) {
      Map<String, dynamic> wordMap = wordsMap[i];
      wordMap["vocId"] = vocId;
      print(wordMap);

      List<Map<String, dynamic>>? answersMap = wordMap.remove("answers");
      String? answer = wordMap.remove("definition");

      Word word = Word.fromMap(wordMap);
      int wordId = await createWord(word);

      // TODO: Handle no answers at all on import
      if (answer != null) {
        await createAnswer(
          Answer(answer: answer, wordId: wordId, vocId: vocId),
        );
      }

      if (answersMap != null) {
        for (var j = 0; j < answersMap.length; j++) {
          Map<String, dynamic> answerMap = answersMap[j];
          answerMap["wordId"] = wordId;
          answerMap["vocId"] = vocId;
          print(answerMap);
          await createAnswer(Answer.fromMap(answerMap));
        }
      }
    }

    for (var i = 0; i < subsetsMap.length; i++) {
      Map<String, dynamic> subsetMap = subsetsMap[i];
      subsetMap["vocId"] = vocId;
      print(subsetMap);

      Subset subset = Subset.fromMap(subsetMap);
      await createSubset(subset);
    }
  }

  // static Future importVoc(String code) async {
  //   Map<String, dynamic> jsonData = jsonDecode(code);
  //   Voc voc = Voc.fromMap(jsonData);
  //   int vocId = await createVoc(voc);
  //   List<Map<String, dynamic>> wordsMap = jsonData["words"];
  //   for (var i = 0; i < wordsMap.length; i++) {
  //     wordsMap[i]["vocId"] = vocId;
  //     Word word = Word.fromMap(wordsMap[i]);
  //     await createWord(word);
  //   }
  // }

  // Future<String> export({bool isEncrypted = false}) async {
  //   print('GENERATE BACKUP');

  //   var dbs = await DatabaseService.initializeDb();

  //   List data = [];

  //   List<Map<String, dynamic>> listMaps = [];

  //   for (var i = 0; i < tables.length; i++) {
  //     listMaps = await dbs.query(tables[i]);

  //     data.add(listMaps);
  //   }

  //   List backups = [tables, data];

  //   String jsonData = jsonEncode(backups);
  //   print(jsonData);
  //   return jsonData;
  // }

  // Future<void> import(String backup) async {
  //   print(backup);
  //   var dbs = await DatabaseService.initializeDb();

  //   Batch batch = dbs.batch();

  //   List jsonData = jsonDecode(backup);
  //   print(jsonData);
  //   List<Voc> actualVocs = await DatabaseService.getVocs();

  //   for (var i = 0; i < jsonData[0].length; i++) {
  //     for (var k = 0; k < jsonData[1][i].length; k++) {
  //       if (actualVocs
  //           .where((recipe) => recipe.title == jsonData[1][i][k]["title"])
  //           .isEmpty) {
  //         jsonData[1][i][k]["id"] = null;
  //         batch.insert(jsonData[0][i], jsonData[1][i][k]);
  //       }
  //     }
  //   }

  //   await batch.commit(continueOnError: false, noResult: true);

  //   print('RESTORE BACKUP');
  // }
}
