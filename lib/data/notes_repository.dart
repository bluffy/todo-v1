import 'dart:async';
import 'dart:ffi';

import 'package:cbl/cbl.dart';
import 'package:collection/collection.dart';

//import 'package:rxdart/rxdart.dart';

//import '../c

class NoteModel {
  String? id;
  String? title;
  String? description;
  int? sort;
  int? isDone;
  String? date;
  String? time;
  int? dateTime;
  int? status;
  String type = "note";

  NoteModel({
    this.id,
    this.title,
    this.description,
    this.sort,
    this.isDone,
    this.date,
    this.time,
    this.dateTime,
    this.status,
  });
  NoteModel nodeModelFromMutal(MutableDocument document) {
    return NoteModel(
      id: document.id,
      title: document.string('title'),
      description: document.string('description'),
      sort: document.integer('sort'),
      isDone: document.integer('isDone'),
      date: document.string('date'),
      time: document.string('string'),
      dateTime: document.integer('dateTime'),
      status: document.integer('status'),
    );
  }

  void fillWithModel(MutableDocument mutableDoc) {
    mutableDoc['type'].string = type;

    if (sort == null || sort == 0) {
      mutableDoc['sort'].integer = DateTime.now().microsecondsSinceEpoch;
    }
    if (title != null) {
      mutableDoc['title'].string = title;
    }
    if (description != null) {
      mutableDoc['description'].string = description;
    }
    if (description != null) {
      mutableDoc['description'].string = description;
    }
    if (time != null) {
      mutableDoc['time'].string = time;
    }
    if (dateTime != null) {
      mutableDoc['dateTime'].integer = dateTime!;
    }
    if (status != null) {
      mutableDoc['status'].integer = status!;
    }
    if (sort != null) {
      mutableDoc['sort'].integer = sort!;
    }
  }

  /*
  Map<String, dynamic> forInsert() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['title'] = title;
    data['description'] = description;
    data['isDone'] = isDone;
    data['date'] = date;
    data['time'] = time;
    data['dateTime'] = dateTime;
    data['status'] = status;
    data['sort'] = sort;
    return data;
  }*/

}

class NotesRepository {
  NotesRepository({required this.database});

  final AsyncDatabase database;
  Future<MutableDocument> createNote({
    required NoteModel model,
  }) async {
    // In Couchbase Lite, data is stored in JSON like documents. The default
    // constructor of MutableDocument creates a new document with a randomly
    // generated id.
    if (model.sort == null || model.sort == 0) {
      model.sort = DateTime.now().microsecondsSinceEpoch;
    }

    final mutableDoc = MutableDocument();
    model.fillWithModel(mutableDoc);

    // Now save the new note in the database.
    await database.saveDocument(mutableDoc);

    return mutableDoc;
  }

  Future<void> updateNote({
    required NoteModel model,
  }) async {
    // In Couchbase Lite, data is stored in JSON like documents. The default
    // constructor of MutableDocument creates a new document with a randomly
    // generated id.

    final doc = (await database.document(model.id.toString()))!;

    // Now save the new note in the database.
    final mutableDoc = doc.toMutable();
    model.fillWithModel(mutableDoc);
    await database.saveDocument(mutableDoc);
  }

  /// Returns the current value of the counter with the given [id] from the
  /// database.
  Future<int> counterValue(String id) async {
    final query = _buildCounterValueQuery();
    await query.setParameters(Parameters({'COUNTER_ID': id}));
    final resultSet = await query.execute();
    return _countValueQueryResult(resultSet);
  }

  AsyncQuery _buildCounterValueQuery() {
    final counterId = Expression.property('counterId');
    var deltaSum = Function_.sum(Expression.property('delta'));

    return QueryBuilder.createAsync()
        .select(SelectResult.expression(deltaSum))
        .from(DataSource.database(database))
        .where(counterId.equalTo(Expression.parameter('COUNTER_ID')))
        .groupBy(counterId);
  }

  Future<int> _countValueQueryResult(ResultSet resultSet) async {
    final results = await resultSet.allResults();
    return results.firstOrNull?.integer(0) ?? 0;
  }

  Future<NoteModel> getNote(String id) async {
    final document = (await database.document(id))!;
    return NoteModel(
      id: document.id,
      title: document.string('title'),
      description: document.string('description'),
      sort: document.integer('sort'),
      date: document.string('date'),
      dateTime: document.integer('dateTime'),
      isDone: document.integer('isDone'),
      status: document.integer('status'),
      time: document.string('string'),
    );
  }

  Future<List<NoteSearchResult>> searchNotes(/*Query queryString*/) async {
    // Creating a query has some overhead and if a query is executed
    // many times, it should be created once and reused. For simplicity
    // we don't do that here.
    /*
    final query = await Query.fromN1ql(
      database,
      r'''
    SELECT META().id AS id, title
    FROM _
    WHERE type = 'note' AND match(note-fts, $query)
    ORDER BY rank(note-fts)
    LIMIT 10
    ''',
    ); 
    WHERE AND  MATCH('note-fts', 'title')
    */
    final query = await Query.fromN1ql(
      database,
      r'''
    SELECT META().id AS id, title, sort
    FROM _ 
     WHERE  type = 'note'
    ORDER BY sort desc  
    LIMIT 1000
    ''',
    );

    // Query parameters are defined by prefixing an identifier with `$`.
    //await query.setParameters(Parameters({'query': '$queryString*'}));

    // Each time a query is executed, its results are returned in a ResultSet.
    final resultSet = await query.execute();

    // To create the NoteSearchResults, we turn the ResultSet into a stream
    // and collect the results into a List, after transforming them into
    // NoteSearchResults.
    return resultSet.asStream().map(NoteSearchResult.fromResult).toList();
  }
}

class NoteSearchResult {
  NoteSearchResult({required this.id, required this.title, required this.sort});

  /// This method creates a NoteSearchResult from a query result.
  static NoteSearchResult fromResult(Result result) => NoteSearchResult(
        // The Result type has typed getters, to extract values from a result.
        id: result.string('id')!,
        title: result.string('title')!,
        sort: result.integer('sort'),
      );

  final String id;
  final String title;
  final int sort;
}
