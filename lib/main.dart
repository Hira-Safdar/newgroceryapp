import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  print('Firebase initialized successfully');// Initialize Firebase here
  runApp(const MyApp());
}

class GroceryItem {
  String id;
  String name;
  bool isPurchased;

  GroceryItem({required this.id, required this.name, this.isPurchased = false});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isPurchased': isPurchased,
    };
  }

  factory GroceryItem.fromMap(String id, Map<String, dynamic> map) {
    return GroceryItem(
      id: id,
      name: map['name'],
      isPurchased: map['isPurchased'] ?? false,
    );
  }
}

class GroceryProvider with ChangeNotifier {
  final DatabaseReference _groceryRef = FirebaseDatabase.instance.ref().child('grocery_list');
  final List<GroceryItem> _groceryItems = [];

  List<GroceryItem> get groceryItems => _groceryItems;

  GroceryProvider() {
    _loadItems();
  }

  void _loadItems() {
    _groceryRef.onChildAdded.listen((event) {
      final groceryItem = GroceryItem.fromMap(event.snapshot.key!, event.snapshot.value as Map<String, dynamic>);
      _groceryItems.add(groceryItem);
      notifyListeners();
    });

    _groceryRef.onChildChanged.listen((event) {
      final updatedItem = GroceryItem.fromMap(event.snapshot.key!, event.snapshot.value as Map<String, dynamic>);
      final index = _groceryItems.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        _groceryItems[index] = updatedItem;
        notifyListeners();
      }
    });

    _groceryRef.onChildRemoved.listen((event) {
      final removedItem = GroceryItem.fromMap(event.snapshot.key!, event.snapshot.value as Map<String, dynamic>);
      _groceryItems.removeWhere((item) => item.id == removedItem.id);
      notifyListeners();
    });
  }

  Future<void> addItem(String name) async {
    final newItem = GroceryItem(id: DateTime.now().toString(), name: name);
    await _groceryRef.child(newItem.id).set(newItem.toMap());
  }

  Future<void> updateItem(GroceryItem item) async {
    await _groceryRef.child(item.id).update(item.toMap());
  }

  Future<void> deleteItem(String id) async {
    await _groceryRef.child(id).remove();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GroceryProvider(),
      child: MaterialApp(
        title: 'Grocery List',
        theme: ThemeData(
          primarySwatch: Colors.green,
        ),
        home: GroceryListScreen(),
      ),
    );
  }
}

class GroceryListScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groceryProvider = Provider.of<GroceryProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Grocery List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Enter item name'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      groceryProvider.addItem(_controller.text);
                      _controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: groceryProvider.groceryItems.length,
              itemBuilder: (context, index) {
                final item = groceryProvider.groceryItems[index];
                return ListTile(
                  title: Text(item.name),
                  trailing: Checkbox(
                    value: item.isPurchased,
                    onChanged: (value) {
                      item.isPurchased = value!;
                      groceryProvider.updateItem(item);
                    },
                  ),
                  onLongPress: () {
                    groceryProvider.deleteItem(item.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}