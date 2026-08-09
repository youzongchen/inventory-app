import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/inventory_state.dart';
import '../widgets/edit_product_dialog.dart';

const _palette = [
  Color(0xFF2F5597),
  Color(0xFF70AD47),
  Color(0xFFED7D31),
  Color(0xFFFFC000),
  Color(0xFF7030A0),
  Color(0xFF00B0F0),
  Color(0xFFC00000),
  Color(0xFF808080),
];

Color _colorFor(String key, List<String> keys) {
  final idx = keys.indexOf(key);
  return _palette[idx % _palette.length];
}

const _mobileBreakpoint = 700.0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _location = '全部';
  String _category = '全部';
  String _brand = '全部';
  String _status = '良品'; // '良品' or '毀損' - which stock to look at
  final _searchCtrl = TextEditingController();
  String _search = '';
  // Mobile only: which single chart to show ('category' or 'item').
  String _mobileChart = 'category';

  int _qtyFor(OverviewRow r) => _status == '良品' ? r.goodQty : r.damagedInStock;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    var allRows = state.overview(location: _location);
    if (_brand != '全部') {
      allRows = allRows.where((r) => r.brand == _brand).toList();
    }
    allRows = allRows.where((r) => _qtyFor(r) > 0).toList();
    final categories = ['全部', ...state.categories];
    final brands = ['全部', ...state.brands];

    // Chart 1: quantity distribution across all categories (respects location filter only).
    final byCategory = <String, int>{};
    for (final r in allRows) {
      byCategory[r.category] = (byCategory[r.category] ?? 0) + _qtyFor(r);
    }
    final categoryKeys = byCategory.keys.toList();

    // Chart 2: item distribution within the selected category.
    final withinCategory = _category == '全部'
        ? <OverviewRow>[]
        : allRows.where((r) => r.category == _category).toList();
    final itemKeys = withinCategory.map((r) => r.name).toList();

    // Total inventory value for whatever's currently in scope (location + category filters).
    final totalValue = (_category == '全部' ? allRows : withinCategory)
        .fold<double>(0, (sum, r) => sum + _qtyFor(r) * (r.cost ?? 0));

    // Table rows: filtered by category + search keyword.
    var tableRows = _category == '全部' ? allRows : withinCategory;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      tableRows = tableRows
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.barcode.toLowerCase().contains(q) ||
              r.brand.toLowerCase().contains(q))
          .toList();
    }

    final categoryPie = byCategory.isEmpty
        ? const _EmptyChart()
        : PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 32,
            sections: byCategory.entries
                .map((e) => PieChartSectionData(
                      value: e.value.toDouble(),
                      title: byCategory.length <= 8 ? e.key : '',
                      color: _colorFor(e.key, categoryKeys),
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ));

    final itemPie = withinCategory.isEmpty
        ? const _EmptyChart()
        : PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 32,
            sections: withinCategory
                .map((r) => PieChartSectionData(
                      value: _qtyFor(r).toDouble(),
                      title: withinCategory.length <= 8
                          ? (r.name.length > 6 ? '${r.name.substring(0, 6)}…' : r.name)
                          : '',
                      color: _colorFor(r.name, itemKeys),
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ));

    final valueStat = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            totalValue.toStringAsFixed(0),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF2F5597)),
          ),
          const SizedBox(height: 6),
          Text(
            _category == '全部' ? '全部類別' : _category,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );

    return Scaffold(
      // The filters+chart above the table are already a tight fit on phones;
      // letting the keyboard shrink available height (the default) pushes the
      // fixed-height chart past the bottom of the screen. Let the keyboard
      // overlay instead - the search field stays visible above it either way.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('庫存管理')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _location,
                  items: ['全部', ...kLocations]
                      .map((l) => DropdownMenuItem(value: l, child: Text('地點：$l')))
                      .toList(),
                  onChanged: (v) => setState(() => _location = v!),
                ),
                DropdownButton<String>(
                  value: _category,
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text('類別：$c'))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: '良品', child: Text('狀態：良品')),
                    DropdownMenuItem(value: '毀損', child: Text('狀態：毀損')),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                DropdownButton<String>(
                  value: _brand,
                  items: brands.map((b) => DropdownMenuItem(value: b, child: Text('品牌：$b'))).toList(),
                  onChanged: (v) => setState(() => _brand = v!),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋品名 / 條碼 / 品牌',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < _mobileBreakpoint;
                if (!isMobile) {
                  return SizedBox(
                    height: 240,
                    child: Row(
                      children: [
                        Expanded(child: _ChartCard(title: '全部類別分布（數量）', child: categoryPie)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChartCard(
                            title: _category == '全部' ? '品項分布（請先選擇類別）' : '「$_category」品項分布',
                            child: itemPie,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _ChartCard(title: '庫存金額', child: valueStat)),
                      ],
                    ),
                  );
                }
                // Mobile: charts are cramped 3-up, so show one larger chart at a
                // time picked from a dropdown, plus a slim inline value stat.
                final chartTitle = _mobileChart == 'category'
                    ? '全部類別分布（數量）'
                    : (_category == '全部' ? '品項分布（請先選擇類別）' : '「$_category」品項分布');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _mobileChart,
                          items: const [
                            DropdownMenuItem(value: 'category', child: Text('圖表：全部類別分布')),
                            DropdownMenuItem(value: 'item', child: Text('圖表：品項分布')),
                          ],
                          onChanged: (v) => setState(() => _mobileChart = v!),
                        ),
                        const Spacer(),
                        Text('庫存金額：', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          totalValue.toStringAsFixed(0),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2F5597), fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: _ChartCard(
                        title: chartTitle,
                        child: _mobileChart == 'category' ? categoryPie : itemPie,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: tableRows.isEmpty
                    ? const Center(child: Text('沒有符合條件的資料', style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('')),
                              const DataColumn(label: Text('品牌')),
                              const DataColumn(label: Text('類別')),
                              const DataColumn(label: Text('品名')),
                              const DataColumn(label: Text('條碼')),
                              const DataColumn(label: Text('地點')),
                              DataColumn(label: Text('$_status庫存'), numeric: true),
                              const DataColumn(label: Text('良品'), numeric: true),
                              const DataColumn(label: Text('損壞在庫'), numeric: true),
                              const DataColumn(label: Text('成本'), numeric: true),
                              const DataColumn(label: Text('庫存金額'), numeric: true),
                              const DataColumn(label: Text('最近效期')),
                            ],
                            rows: tableRows
                                .map((r) => DataRow(cells: [
                                      DataCell(IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        tooltip: '編輯',
                                        onPressed: () => showEditProductDialog(context, r),
                                      )),
                                      DataCell(Text(r.brand)),
                                      DataCell(Text(r.category)),
                                      DataCell(Text(r.name)),
                                      DataCell(Text(r.barcode)),
                                      DataCell(Text(r.location)),
                                      DataCell(Text(
                                        '${_qtyFor(r)}',
                                        style: TextStyle(
                                          color: r.safetyStock != null && _qtyFor(r) <= r.safetyStock!
                                              ? Colors.red
                                              : null,
                                          fontWeight: r.safetyStock != null && _qtyFor(r) <= r.safetyStock!
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                      )),
                                      DataCell(Text('${r.goodQty}')),
                                      DataCell(Text(
                                        '${r.damagedInStock}',
                                        style: TextStyle(
                                          color: r.damagedInStock > 0 ? Colors.orange.shade800 : null,
                                          fontWeight: r.damagedInStock > 0 ? FontWeight.bold : null,
                                        ),
                                      )),
                                      DataCell(Text(r.cost?.toStringAsFixed(0) ?? '-')),
                                      DataCell(Text(() {
                                        final v = _qtyFor(r) * (r.cost ?? 0);
                                        return v > 0 ? v.toStringAsFixed(0) : '-';
                                      }())),
                                      DataCell(_ExpiryText(r.nearestExpiry)),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('無資料', style: TextStyle(color: Colors.grey, fontSize: 12)));
  }
}

class _ExpiryText extends StatelessWidget {
  final DateTime? date;
  const _ExpiryText(this.date);

  @override
  Widget build(BuildContext context) {
    if (date == null) return const Text('-');
    final daysLeft = date!.difference(DateTime.now()).inDays;
    final urgent = daysLeft <= 30; // expired or expiring within a month
    return Text(
      '${date!.year}/${date!.month}/${date!.day}',
      style: TextStyle(
        color: urgent ? Colors.red : null,
        fontWeight: urgent ? FontWeight.bold : null,
      ),
    );
  }
}
