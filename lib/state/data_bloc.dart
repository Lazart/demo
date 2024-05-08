import 'dart:async';
import 'dart:convert';
import 'dart:developer' as Logger;
import 'dart:math';
import 'package:rxdart/rxdart.dart';
import 'package:hive/hive.dart';
import '../services/data_service.dart';
import '../websocket/mock_websocket.dart';

class DataBloc {
  late BehaviorSubject<List<int>> _dataSubject;
  late BehaviorSubject<List<int>> _filteredDataSubject;
  late BehaviorSubject<List<int>> _colourSubject;
  late BehaviorSubject<List<String>> _filtersSubject;
  final DataService _dataService = DataService();
  final int _bufferSize = 90;
  final int _pollingInterval = 3; // Polling interval in minutes
  late Timer _pollingTimer;
  late MockWebSocket _mockWebSocket;
  int _firstItemValue = 1;
  bool _isFirstTimeUpdated = false;
  late Box<int> _hiveBox;
  final jsonEncoder = const JsonEncoder();

  DataBloc() {
    _dataSubject = BehaviorSubject<List<int>>.seeded([]);
    _filteredDataSubject = BehaviorSubject<List<int>>.seeded([]);
    _colourSubject = BehaviorSubject<List<int>>.seeded([]);
    _filtersSubject = BehaviorSubject<List<String>>.seeded([]);
    _hiveBox = Hive.box<int>('items');
    _mockWebSocket = MockWebSocket();
    // _startPolling();
    // _setupWebSocketConnection();
  }

  Stream<List<int>> get dataStream => _filteredDataSubject.stream;
  Stream<List<int>> get colourStream => _colourSubject.stream;
  Stream<List<String>> get filtersStream => _filtersSubject.stream;

  int get firstItemValue => _firstItemValue;
  bool get isFirstTimeUpdated => _isFirstTimeUpdated;

  void loadInitialData({required int perPage}) async {
    final initialData =
        List.generate(perPage, (index) => index + _firstItemValue);
    _dataSubject.add(initialData);
    _filteredDataSubject.add(initialData);
  }

  Future<void> loadData(
      {required bool loadEarlier, required int perPage}) async {
    final currentData = _dataSubject.value;
    if (loadEarlier) {
      _firstItemValue -= perPage;
      final newData = await _fetchOrRetrieveData(
        perPage: perPage,
        firstItemValue: _firstItemValue,
        loadEarlier: loadEarlier,
      );
      _dataSubject.add(newData + currentData);
    } else {
      final newItemValue = currentData.last + 1;

      final newData = await _fetchOrRetrieveData(
        perPage: perPage,
        firstItemValue: newItemValue,
        loadEarlier: loadEarlier,
      );

      _dataSubject.add(currentData + newData);
    }

    // Ensure data does not exceed buffer size
    if (_dataSubject.value.length > _bufferSize) {
      if (loadEarlier) {
        _dataSubject.add(_dataSubject.value.sublist(0, _bufferSize));
      } else {
        _isFirstTimeUpdated = true;

        _dataSubject.add(
          _dataSubject.value.sublist(_dataSubject.value.length - _bufferSize),
        );
        _firstItemValue = _dataSubject.value.first;
      }
    }

    // Update filtered data after new data is loaded
    _filteredDataSubject.add(_dataSubject.value);
  }

  Future<List<int>> _fetchOrRetrieveData({
    required int perPage,
    required int firstItemValue,
    required bool loadEarlier,
  }) async {
    final List<int> fetchedData;

    // Check if data is already available in the local database
    if (_hiveBox.containsKey(firstItemValue)) {
      fetchedData = List.generate(perPage, (index) => firstItemValue + index)
          .where((item) => _hiveBox.containsKey(item))
          .map((item) => _hiveBox.get(item)!)
          .toList();
    } else {
      // Otherwise, fetch data via the DataService
      fetchedData = await _dataService.fetchData(
        perPage: perPage,
        firstItemValue: firstItemValue,
        loadEarlier: loadEarlier,
      );

      // Cache fetched data locally in the database
      for (final item in fetchedData) {
        _hiveBox.put(item, item);
      }
    }

    return fetchedData;
  }

  void filterData(String query) {
    final filters = List<String>.from(_filtersSubject.value);
    if (query.isNotEmpty && !filters.contains(query)) {
      filters.add(query);
    }
    _filtersSubject.add(filters);

    _applyFilters();
  }

  void removeFilter(String filter) {
    final filters = List<String>.from(_filtersSubject.value);
    filters.remove(filter);
    _filtersSubject.add(filters);

    _applyFilters();
  }

  void _applyFilters() {
    final filters = _filtersSubject.value;
    final data = _dataSubject.value;

    if (filters.isEmpty) {
      _filteredDataSubject.add(data);
    } else {
      final filteredData = data.where((item) {
        return filters.every((filter) => item.toString().contains(filter));
      }).toList();
      _filteredDataSubject.add(filteredData);
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(
      Duration(minutes: _pollingInterval),
      (Timer timer) async {
        const perPage =
            30; // Example page size, can be replaced or made dynamic
        final currentData = _dataSubject.value;
        final newItemValue = currentData.last + 1;
        Logger.log('Polling... from item: $newItemValue');

        await loadData(loadEarlier: false, perPage: perPage);
      },
    );
  }

  void _setupWebSocketConnection() {
    _mockWebSocket.connect(
      'wss://demo.piesocket.com/v3/channel_123?api_key=VCXCEuvhGcBDP7XhiJJUDvR1e1D3eiVjgZ9VRiaV&notify_self',
    );

    _mockWebSocket.stream.listen((message) {
      Logger.log('WebSocket message received: $message');
      if (message.startsWith('new_items')) {
        const perPage = 10; // New items count (example)
        loadData(loadEarlier: false, perPage: perPage);
      } else if (message.startsWith('{ "colour":')) {
        final parsedJson = jsonDecode(message);
        final List<int> colourList = List<int>.from(parsedJson['colour']);
        Logger.log('Received color list: $colourList');
        _colourSubject.add(colourList);
      }
    });

    // Simulate an incoming message every 1 minute
    Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      _mockWebSocket.simulateIncomingMessage('new_items');
    });

    // Simulate random color assignment every 5 seconds
    Timer.periodic(const Duration(seconds: 6), (Timer timer) {
      final currentData = _dataSubject.value;

      var rng = Random();
      final List<int> colourList = [];
      for (var i = currentData.first; i < currentData.last; i++) {
        colourList.add(rng.nextInt(5));
      }
      final msg = '{ "colour": ${jsonEncoder.convert(colourList)}}';
      _mockWebSocket.simulateIncomingMessage(msg);
    });
  }

  void dispose() {
    _pollingTimer.cancel();
    _mockWebSocket.disconnect();
    _dataSubject.close();
    _filteredDataSubject.close();
    _colourSubject.close();
    _filtersSubject.close();
  }
}
