import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

/// Opens the workbook backing the current data source in whatever the OS/
/// browser considers the default handler - the local .xlsx via the file
/// picker's path (desktop/mobile), or the actual Google Sheet URL (web +
/// Sheets mode, if the user bothered to fill it in when connecting). There's
/// nothing to open for the web "local file" mode - only a bytes copy lives in
/// browser memory, no real path exists.
Future<void> _openUnderlyingFile(BuildContext context, InventoryState state) async {
  Uri? target;
  if (state.filePath != null) {
    target = Uri.file(state.filePath!);
  } else if (state.sheetsSheetUrl != null && state.sheetsSheetUrl!.isNotEmpty) {
    target = Uri.tryParse(state.sheetsSheetUrl!);
  }
  if (target == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('此資料來源模式沒有可直接開啟的底層檔案（網頁版本機檔案模式僅存在瀏覽器記憶體中）')),
    );
    return;
  }
  try {
    final ok = await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('無法開啟：$target')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('開啟失敗：$e')));
    }
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _location = '全部';
  String _category = '全部';
  String _brand = '全部';
  String _size = '全部';
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
    if (_size != '全部') {
      allRows = allRows.where((r) => (r.size ?? '') == _size).toList();
    }
    allRows = allRows.where((r) => _qtyFor(r) > 0).toList();
    final categories = ['全部', ...state.categories];
    final brands = ['全部', ...state.brands];
    final sizes = ['全部', ...state.sizes];

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
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('庫存管理'),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: '開啟底層 Excel / 試算表編輯更底層的資料',
              onPressed: () => _openUnderlyingFile(context, state),
            ),
          ],
        ),
      ),
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
                DropdownButton<String>(
                  value: _size,
                  items: sizes.map((s) => DropdownMenuItem(value: s, child: Text('尺寸：$s'))).toList(),
                  onChanged: (v) => setState(() => _size = v!),
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
                    : _InventoryPlutoGrid(
                        rows: tableRows,
                        statusLabel: _status,
                        qtyFor: _qtyFor,
                        onEdit: (r) => showEditProductDialog(context, r),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 庫存管理 table itself, built on PlutoGrid instead of DataTable so it
/// gets (for free) a header row that stays fixed while the body scrolls,
/// per-column drag-to-resize, and pinned/frozen leading columns.
///
/// PlutoGrid does NOT pick up new [rows]/[columns] automatically on rebuild
/// (its State.didUpdateWidget only re-applies configuration/mode) - row data
/// has to be pushed into the PlutoGridStateManager explicitly, which is what
/// [didUpdateWidget] below does. Column definitions (including frozen/resize
/// settings) are built once in [initState] and left alone, except for the
/// quantity column's title, which is mutated in place when the 良品/毀損
/// toggle changes.
class _InventoryPlutoGrid extends StatefulWidget {
  final List<OverviewRow> rows;
  final String statusLabel;
  final int Function(OverviewRow) qtyFor;
  final void Function(OverviewRow) onEdit;

  const _InventoryPlutoGrid({
    required this.rows,
    required this.statusLabel,
    required this.qtyFor,
    required this.onEdit,
  });

  @override
  State<_InventoryPlutoGrid> createState() => _InventoryPlutoGridState();
}

class _InventoryPlutoGridState extends State<_InventoryPlutoGrid> {
  PlutoGridStateManager? _stateManager;
  late final List<PlutoColumn> _columns;
  late final PlutoColumn _qtyColumn;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    _qtyColumn = PlutoColumn(
      title: '${widget.statusLabel}庫存',
      field: 'qty',
      type: PlutoColumnType.text(),
      textAlign: PlutoColumnTextAlign.right,
      width: 110,
      enableColumnDrag: false,
      enableSorting: false,
      enableContextMenu: false,
      enableFilterMenuItem: false,
      renderer: (ctx) {
        final row = _rowFor(ctx);
        final qty = row == null ? ctx.cell.value.toString() : widget.qtyFor(row).toString();
        final urgent = row != null && row.safetyStock != null && widget.qtyFor(row) <= row.safetyStock!;
        return Text(
          qty,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: urgent ? Colors.red : null,
            fontWeight: urgent ? FontWeight.bold : null,
          ),
        );
      },
    );
    _columns = [
      PlutoColumn(
        title: '',
        field: 'edit',
        type: PlutoColumnType.text(),
        width: 56,
        minWidth: 56,
        frozen: PlutoColumnFrozen.start,
        enableColumnDrag: false,
        enableSorting: false,
        enableContextMenu: false,
        enableFilterMenuItem: false,
        enableDropToResize: false,
        renderer: (ctx) {
          final row = _rowFor(ctx);
          return IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: '編輯',
            onPressed: row == null ? null : () => widget.onEdit(row),
          );
        },
      ),
      _textColumn('brand', '品牌', frozen: true),
      _textColumn('category', '類別', frozen: true),
      _textColumn('name', '品名', frozen: true, width: 160),
      _textColumn('size', '尺寸', width: 90),
      _textColumn('barcode', '條碼', width: 130),
      _textColumn('location', '地點', width: 90),
      _qtyColumn,
      _numberColumn('good', '良品'),
      PlutoColumn(
        title: '損壞在庫',
        field: 'damagedInStock',
        type: PlutoColumnType.text(),
        textAlign: PlutoColumnTextAlign.right,
        width: 100,
        enableColumnDrag: false,
        enableSorting: false,
        enableContextMenu: false,
        enableFilterMenuItem: false,
        renderer: (ctx) {
          final row = _rowFor(ctx);
          final damaged = row?.damagedInStock ?? 0;
          return Text(
            '$damaged',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: damaged > 0 ? Colors.orange.shade800 : null,
              fontWeight: damaged > 0 ? FontWeight.bold : null,
            ),
          );
        },
      ),
      _numberColumn('cost', '成本'),
      _numberColumn('stockValue', '庫存金額', width: 110),
      PlutoColumn(
        title: '最近效期',
        field: 'nearestExpiry',
        type: PlutoColumnType.text(),
        width: 110,
        enableColumnDrag: false,
        enableSorting: false,
        enableContextMenu: false,
        enableFilterMenuItem: false,
        renderer: (ctx) => _ExpiryText(_rowFor(ctx)?.nearestExpiry),
      ),
      PlutoColumn(
        title: '入庫時間',
        field: 'entryTime',
        type: PlutoColumnType.text(),
        width: 130,
        enableColumnDrag: false,
        enableSorting: false,
        enableContextMenu: false,
        enableFilterMenuItem: false,
        renderer: (ctx) => _EntryTimeText(_rowFor(ctx)?.nearestExpiryEntryTime),
      ),
    ];
  }

  PlutoColumn _textColumn(String field, String title, {bool frozen = false, double width = 100}) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.text(),
      width: width,
      frozen: frozen ? PlutoColumnFrozen.start : PlutoColumnFrozen.none,
      enableColumnDrag: false,
      enableSorting: false,
      enableContextMenu: false,
      enableFilterMenuItem: false,
    );
  }

  PlutoColumn _numberColumn(String field, String title, {double width = 90}) {
    return PlutoColumn(
      title: title,
      field: field,
      type: PlutoColumnType.text(),
      textAlign: PlutoColumnTextAlign.right,
      width: width,
      enableColumnDrag: false,
      enableSorting: false,
      enableContextMenu: false,
      enableFilterMenuItem: false,
    );
  }

  /// Rows carry their own barcode/location so renderers can look the matching
  /// [OverviewRow] back up regardless of any internal reordering PlutoGrid
  /// might do - safer than trusting rowIdx to line up with widget.rows.
  OverviewRow? _rowFor(PlutoColumnRendererContext ctx) {
    final barcode = ctx.row.cells['barcode']!.value as String;
    final location = ctx.row.cells['location']!.value as String;
    for (final r in widget.rows) {
      if (r.barcode == barcode && r.location == location) return r;
    }
    return null;
  }

  List<PlutoRow> _buildRows() {
    return widget.rows.map((r) {
      final stockValue = widget.qtyFor(r) * (r.cost ?? 0);
      return PlutoRow(cells: {
        'edit': PlutoCell(value: ''),
        'brand': PlutoCell(value: r.brand),
        'category': PlutoCell(value: r.category),
        'name': PlutoCell(value: r.name),
        'size': PlutoCell(value: r.size ?? ''),
        'barcode': PlutoCell(value: r.barcode),
        'location': PlutoCell(value: r.location),
        'qty': PlutoCell(value: widget.qtyFor(r)),
        'good': PlutoCell(value: r.goodQty),
        'damagedInStock': PlutoCell(value: r.damagedInStock),
        'cost': PlutoCell(value: r.cost?.toStringAsFixed(0) ?? '-'),
        'stockValue': PlutoCell(value: stockValue > 0 ? stockValue.toStringAsFixed(0) : '-'),
        'nearestExpiry': PlutoCell(value: r.nearestExpiry?.toIso8601String() ?? ''),
        'entryTime': PlutoCell(value: r.nearestExpiryEntryTime?.toIso8601String() ?? ''),
      });
    }).toList();
  }

  String _signature() => widget.rows
      .map((r) =>
          '${r.barcode}#${r.location}#${widget.qtyFor(r)}#${r.goodQty}#${r.damagedInStock}#${r.cost}#${r.size}#${r.nearestExpiry}#${r.nearestExpiryEntryTime}')
      .join(';');

  @override
  void didUpdateWidget(covariant _InventoryPlutoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusLabel != widget.statusLabel) {
      _qtyColumn.title = '${widget.statusLabel}庫存';
      _stateManager?.notifyListeners();
    }
    final sig = _signature();
    if (sig != _lastSignature) {
      _lastSignature = sig;
      final mgr = _stateManager;
      if (mgr != null) {
        mgr.removeAllRows(notify: false);
        mgr.appendRows(_buildRows());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _lastSignature = _signature();
    return PlutoGrid(
      columns: _columns,
      rows: _buildRows(),
      onLoaded: (event) {
        _stateManager = event.stateManager;
        _stateManager!.setShowColumnFilter(false);
      },
      configuration: const PlutoGridConfiguration(
        style: PlutoGridStyleConfig(
          gridBorderColor: Colors.transparent,
          borderColor: Color(0xFFEEEEEE),
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

/// Plain (non-urgency-colored) date+time display for the 入庫時間 column.
class _EntryTimeText extends StatelessWidget {
  final DateTime? time;
  const _EntryTimeText(this.time);

  @override
  Widget build(BuildContext context) {
    if (time == null) return const Text('-');
    final t = time!;
    return Text(
      '${t.year}/${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      style: const TextStyle(fontSize: 12),
    );
  }
}
