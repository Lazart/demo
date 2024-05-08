import 'dart:developer';

class DataService {
  Future<List<int>> fetchData(
      {required int perPage,
      required int firstItemValue,
      required bool loadEarlier}) async {
    log('simulate api call from item: $firstItemValue');

    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay

    if (loadEarlier) {
      final newData = List.generate(perPage, (index) => firstItemValue + index);

      return newData;
    } else {
      return List.generate(perPage, (index) => firstItemValue + index);
    }
  }
}
