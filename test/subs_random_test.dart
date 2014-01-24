library subs_random_test;

import "package:unittest/unittest.dart";
import "package:clean_sync/server.dart";
import "dart:async";
import 'dart:math';
import './mongo_provider_test.dart';
import 'package:clean_sync/client.dart';
import 'package:unittest/mock.dart';
import 'package:clean_ajax/client.dart';
import 'package:clean_ajax/client_backend.dart';
import 'package:clean_ajax/server.dart';
import 'package:clean_data/clean_data.dart';
import 'package:logging/logging.dart';


Random rng = new Random();

const PROB_REMOVE = 0.1;
const PROB_ADD = 0.3;

prob(p) {
  return p > rng.nextDouble();
}

final Logger logger = new Logger('clean_sync');


class BareConnectionMock extends Mock implements Connection {}
class IdGeneratorMock extends Mock implements IdGenerator {}

main() {

  var config = new SimpleConfiguration();
  config.timeout = null;
  unittestConfiguration = config;



  hierarchicalLoggingEnabled = true;
  logger.level = Level.WARNING;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.message}');
  });


  DataSet currCollection;
  DataSet wholeCollection;
  MongoDatabase mongodb;
  DataSet sender;
  DataSet receiver;
  DataSet receiverb;
  DataSet receiverc;
  Connection connection;
  Subscription subSender;
  Subscription subReceiver;
  Subscription subReceiverb;
  Subscription subReceiverc;

  Publisher pub;

  mongodb = new MongoDatabase('mongodb://0.0.0.0/mongoProviderTest');

  setUp((){
    return Future.wait(mongodb.init)
    .then((_) => mongodb.dropCollection('random'))
    .then((_) => mongodb.removeLocks()).then((_){
        pub = new Publisher();
        pub.publish('a', (_) {
          return mongodb.collection("random").find({});
        });

        pub.publish('b', (_) {
          return mongodb.collection("random").find({'a': 'hello'});
        });

        pub.publish('c', (_) {
          return mongodb.collection("random").find({'a.a': 'hello'});
        });


        MultiRequestHandler requestHandler = new MultiRequestHandler();
        requestHandler.registerDefaultHandler(pub.handleSyncRequest);
        connection = createLoopBackConnection(requestHandler);

        subSender = new Subscription('a', connection, 'author1', new IdGenerator('a'), {});
        sender = subSender.collection;

        subReceiver = new Subscription('a', connection, 'author2', new IdGenerator('b'), {});
        receiver = subReceiver.collection;
        subReceiverb = new Subscription('b', connection, 'author3', new IdGenerator('c'), {});
        subReceiverc = new Subscription('c', connection, 'author4', new IdGenerator('d'), {});

        receiverb = subReceiverb.collection;
        receiverc = subReceiverc.collection;


    });
  });

  randomChoice(Iterable iter) {
    var list = new List.from(iter);
    return list[rng.nextInt(list.length)];
  }

  var allValues=['hello', 'world', 1];
  var allKeys=['a','b','c'];

  randomChangeMap(Map data) {
    var key = randomChoice(allKeys);
    if (data.containsKey(key)) {
      if (data[key] is Map) {
        randomChangeMap(data[key]);
      } else {
        data[key] = randomChoice(allValues);
      }
    } else {
      data[key] = randomChoice(allValues);
    }

    if (data[key] is! Map && prob(PROB_ADD)) {
      data[key] = new Map();
      randomChangeMap(data[key]);
    }

    if (prob(PROB_REMOVE)) {
      data.remove(key);
    }
  }

  makeRandomChange(DataSet coll) {
    var probAdd = (){
      if(coll.length<5) return 1;
      if(coll.length>15)return 0;
      return rng.nextDouble();
    };

    var probRemove = (){
      if(coll.length>15) return 1;
      if(coll.length<5)return 0;
      return rng.nextDouble();
    };

    if (prob(probAdd())) {
      // add
        logger.finer('before add \n $coll');
        coll.add(new DataMap.from({}), author: null);
        logger.finer('after add');
        return true;
    }
    else if (prob(probRemove())) {
      if (coll.length == 0) return false;
      // remove
        logger.finer('before remo \n $coll');
        coll.remove(randomChoice(coll));
        logger.finer('before remo');
        return true;
    } else {
      // change
      if (coll.length == 0) return false;
      var data = randomChoice(coll);
      if(data!=null){
        logger.finer('before change \n $coll');
        randomChangeMap(data);
        logger.finer('after change: $data');
        return true;
      } else {
        return false;
      }
    }
  }


  test('test random', () {

  var action = (){
    for (int i=0; i<5; i++) {
      Subscription toChangeSub = randomChoice([subSender, subReceiver]);
      makeRandomChange(toChangeSub.collection);
    }
  };

//  var action = (){
//    Subscription toChangeSub = randomChoice([subSender, subReceiver]);
//    logger.fine('$toChangeSub');
//    return makeRandomChange(toChangeSub.collection);
//  };

  var makeExpects = () {
    expect(stripPrivateFieldsList(receiver),
           unorderedEquals(stripPrivateFieldsList(sender)));
    expect(stripPrivateFieldsList(sender.where((d)=>d['a']=='hello')),
           unorderedEquals(stripPrivateFieldsList(receiverb)));
    expect(stripPrivateFieldsList(
        sender.where((d) => (d['a'] is Map && d['a']['a'] == 'hello'))),
        unorderedEquals(stripPrivateFieldsList(receiverc)));
  };

    var times=[100, 200, 400, 800, 1600, 3200, 6400];
//    var times=[300, 400, 800, 1600, 3200];
    var i=0;
    return subSender.initialSync.then((_) =>
    subReceiver.initialSync).then((_) =>
    subReceiverb.initialSync).then((_) =>
    subReceiverc.initialSync).then((_) =>

    Future.forEach(new List.filled(100000, null), (_) {
        print(i++);
        action();
//        sender.where((d) => (d.containsKey('a') && d['a'] is Map && d['a']['a'] == 'hello'));
        print(receiver);
        bool end = false;
        return Future.forEach(times, (time){
          if(end){
            return new Future.value(0);
          } else
          return new Future.delayed(new Duration(milliseconds: time), (){
            try{
              makeExpects();
              end = true;
            } catch(e,s){
              if(time == times.last){
                print('author1 $sender');
                print('author2 $receiver');
                print('author4 $receiverc');

                print(s);
                throw e;
              }
            }
          });
        });
    }));

  });

  skip_test('test subs', () {

    DataMap data = new DataMap.from({'_id': '0'});
    DataMap data1 = new DataMap.from({'_id': '1', 'b': 'bbb'});
    DataMap data2 = new DataMap.from({'_id': '2', 'c': 'ccc'});


//    List actions = [
//      () => sender.add(data, author: null),
//      () => expect(stripPrivateFields(receiver.first), equals(data)),
//      () => expect(receiverb, isEmpty),
//      () => data['a'] = 'hello',
//      () => expect(stripPrivateFields(receiverb.first), equals(data)),
//      () => data.remove('a'),
//      () => expect(receiverb, isEmpty),
//      () => data['a'] = 1,
//      () => expect(receiverc, isEmpty),
//      () => data['a'] = new DataMap.from({}),
//      () => expect(receiverc, isEmpty),
//      () => data['a']['a'] = 'hello',
//      () => expect(stripPrivateFields(receiverc.first), equals(data)),
//    ];

//    List actions = [
//      () => sender.add(data, author: null),
//      () => print(receiver),
//      () => expect(stripPrivateFields(receiver.first), equals(stripPrivateFields(data))),
//      () {print('assign!!!!!'); receiver.first['b'] = 'bbb'; sender.first['b'] = 'bb';},
//      () => print(sender),
//      () => print(receiver),
//      () => expect(stripPrivateFieldsList(sender), equals(stripPrivateFieldsList(receiver))),
//    ];


    List actions = [
      () => print(receiver),
      () => mongodb.collection('random').add({'_id': '0', 'a': 10}, 'ja'),
      () => print(receiver),
      () => mongodb.collection('random').deprecatedChange('0', {'b': 20}, 'ja'),
      () => expect(stripPrivateFieldsList(receiver), unorderedEquals([{'_id': '0', 'a': 10, 'b': 20}])),
      () => mongodb.collection('random').deprecatedChange('0', {'a': {'a': 10}}, 'ja'),
      () => expect(stripPrivateFieldsList(receiver), unorderedEquals([{'_id': '0', 'a': {'a': 10}, 'b': 20}])),

      () => print(receiver),
    ];




    return
    mongodb.dropCollection('random').then((_) =>
    mongodb.removeLocks()).then((_) =>
    subSender.initialSync).then((_) =>
    subReceiver.initialSync).then((_) =>
    subReceiverb.initialSync).then((_) =>
    subReceiverc.initialSync).then((_) =>
    Future.forEach(actions, (action) {
      action();
      return new Future.delayed(new Duration(milliseconds: 200));
    }));

  });
}

