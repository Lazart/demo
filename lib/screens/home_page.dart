import 'package:flutter/material.dart';
import '../state/data_bloc.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DataBloc _dataBloc = DataBloc();
  late ScrollController _scrollController;
  final int _perPage = 30;
  double _itemHeight = 0;
  final GlobalKey _firstItemKey = GlobalKey();
  double _currentScroll = 0;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _dataBloc.loadInitialData(perPage: _perPage);
  }

  @override
  void dispose() {
    _dataBloc.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData({required bool loadEarlier}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    await _dataBloc.loadData(loadEarlier: loadEarlier, perPage: _perPage);

    setState(() {
      _isLoading = false;
    });

    if (_dataBloc.isFirstTimeUpdated && !loadEarlier) {
      _scrollController.jumpTo(_currentScroll - _itemHeight * _perPage);
    } else if (loadEarlier) {
      _scrollController.jumpTo(_currentScroll + _itemHeight * _perPage);
    }
  }

  void _scrollListener() {
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final minScrollExtent = _scrollController.position.minScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    _currentScroll = currentScroll;

    if (currentScroll >= maxScrollExtent - _itemHeight * (_perPage / 2) &&
        !_isLoading) {
      _loadData(loadEarlier: false); // Prefetch more data when scrolling down
    } else if (_dataBloc.firstItemValue > 1 &&
        currentScroll <= minScrollExtent + _itemHeight * (_perPage / 2) &&
        !_isLoading) {
      _loadData(loadEarlier: true); // Load previous data when scrolling up
    }
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim();
    _dataBloc.filterData(query);
    _searchController.clear();
  }

  void _removeFilter(String filter) {
    _dataBloc.removeFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite Scroll with Memory Management'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search...',
                  border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.green.shade300,
                      ),
                      borderRadius: BorderRadius.circular(15.0)),
                ),
                onSubmitted: (_) => _applySearchFilter(),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(left: 100, right: 100),
                      child: ElevatedButton(
                        onPressed: _applySearchFilter,
                        child: const Text('Search'),
                      ))),
            ],
          ),
          StreamBuilder<List<String>>(
            stream: _dataBloc.filtersStream,
            builder: (context, snapshot) {
              final filters = snapshot.data ?? [];
              return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Wrap(
                    spacing: 2.0,
                    runSpacing: 1.0,
                    children: filters
                        .map((filter) => Chip(
                              label: Text(filter),
                              onDeleted: () => _removeFilter(filter),
                            ))
                        .toList(),
                  ));
            },
          ),
          Expanded(
            child: StreamBuilder<List<int>>(
              stream: _dataBloc.dataStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  return StreamBuilder<List<int>>(
                    stream: _dataBloc.colourStream,
                    builder: (context, colourSnapshot) {
                      final colourList = colourSnapshot.data ?? [];

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        controller: _scrollController,
                        itemCount: data.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < data.length) {
                            final key = index == 0 ? _firstItemKey : null;
                            final colorIndex = index < colourList.length
                                ? colourList[index]
                                : 0;
                            final itemColor = _getItemColor(colorIndex);

                            return Card(
                                margin: const EdgeInsets.only(
                                    left: 400, right: 400, bottom: 5),
                                shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: itemColor,
                                    ),
                                    borderRadius: BorderRadius.circular(15.0)),
                                child: ListTile(
                                  key: key,
                                  title: Center(
                                      child: Text(
                                    'Item ${data[index]}',
                                    style: const TextStyle(fontSize: 20.0),
                                  )),
                                ));
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                        },
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getItemColor(int index) {
    const List<Color> colors = [
      Colors.white,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  // Post-render adjustments
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_firstItemKey.currentContext != null && _itemHeight == 0) {
        final RenderBox box =
            _firstItemKey.currentContext!.findRenderObject() as RenderBox;
        setState(() {
          _itemHeight = box.size.height;
        });
      }
    });
  }
}
