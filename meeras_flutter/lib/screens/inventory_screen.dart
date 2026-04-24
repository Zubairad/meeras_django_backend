import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/meeras_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _all = [];
  List _lowStock = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ApiService.getInventory();
    final low = await ApiService.getLowStock();
    setState(() {
      _all = all['data']['results'] ?? all['data'] ?? [];
      _lowStock = low['data']['results'] ?? low['data'] ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isNgoAdmin && !auth.isSystemAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const Center(
          child: Text('Access restricted to NGO admins',
              style: TextStyle(color: MeerasTheme.textMuted)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: MeerasTheme.accent,
          labelColor: MeerasTheme.accent,
          unselectedLabelColor: MeerasTheme.textMuted,
          tabs: [
            const Tab(text: 'All Items'),
            Tab(text: 'Low Stock (${_lowStock.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MeerasTheme.accent))
          : TabBarView(
              controller: _tabs,
              children: [
                _InventoryList(items: _all, onRefresh: _load),
                _InventoryList(items: _lowStock, isLowStock: true, onRefresh: _load),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MeerasTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddItem(context),
      ),
    );
  }

  void _showAddItem(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: MeerasTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Inventory Item',
                style: TextStyle(color: MeerasTheme.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Item name'),
              style: const TextStyle(color: MeerasTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Quantity'),
              style: const TextStyle(color: MeerasTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _load();
                },
                child: const Text('Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  final List items;
  final bool isLowStock;
  final Future<void> Function() onRefresh;

  const _InventoryList({
    required this.items,
    this.isLowStock = false,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(isLowStock ? 'No low stock items' : 'No inventory items',
            style: const TextStyle(color: MeerasTheme.textMuted)),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: MeerasTheme.accent,
      backgroundColor: MeerasTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final qty = item['quantity'] ?? 0;
          final threshold = item['low_stock_threshold'] ?? 10;  // real model field name
          final low = item['is_low_stock'] ?? (qty <= threshold);  // use serializer flag
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MeerasTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: low ? Border.all(color: MeerasTheme.danger.withOpacity(0.3)) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: (low ? MeerasTheme.danger : MeerasTheme.accent).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      color: low ? MeerasTheme.danger : MeerasTheme.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['item_name'] ?? 'Item ${item['id']}',  // real model field
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Qty: $qty • Threshold: $threshold',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (low)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MeerasTheme.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Low',
                        style: TextStyle(color: MeerasTheme.danger,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}