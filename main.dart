// AI 코드 참고
// 출처: ChatGPT(OpenAI)를 활용하여 Flutter 반려견 급여 재고 관리 앱 구현에 도움을 받음.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DogFoodApp());
}

class DogFoodApp extends StatelessWidget {
  const DogFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '반려견 급여 재고 관리',
      theme: ThemeData(
        platform: TargetPlatform.iOS,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xfffaf4e8),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const DogFoodHomePage(),
    );
  }
}

class FeedItem {
  final String petName;
  final String category;
  final String itemName;
  final double weight;
  final double remain;
  final double daily;
  final String unit;
  final String memo;
  final DateTime purchaseDate;

  FeedItem({
    required this.petName,
    required this.category,
    required this.itemName,
    required this.weight,
    required this.remain,
    required this.daily,
    required this.unit,
    required this.memo,
    required this.purchaseDate,
  });

  double get remainDays => daily > 0 ? remain / daily : 0;
  int get remainDaysRounded => remainDays.ceil();
  DateTime get expectedEndDate => purchaseDate.add(Duration(days: remainDaysRounded));

  String get stockStatus {
    if (remainDays < 7) return '부족';
    if (remainDays <= 14) return '주의';
    return '충분';
  }

  Color get statusColor {
    if (remainDays < 7) return const Color(0xffd9534f);
    if (remainDays <= 14) return const Color(0xffd6a328);
    return const Color(0xff329b67);
  }

  double get recommendedDaily => weight * 30;

  String get feedingAssessment {
    final recommended = recommendedDaily;
    if (daily >= recommended * 1.1) {
      return '과다 급여';
    }
    if (daily <= recommended * 0.9) {
      return '부족 급여';
    }
    return '적정 급여';
  }

  String get managementComment {
    if (stockStatus == '부족') {
      return '재고가 부족합니다. 빠른 보충이 필요합니다.';
    }
    if (stockStatus == '주의') {
      return '곧 소진될 수 있으니 사용량을 확인해 주세요.';
    }
    if (feedingAssessment == '과다 급여') {
      return '급여량이 권장량보다 많습니다. 체중 변화를 확인하세요.';
    }
    if (feedingAssessment == '부족 급여') {
      return '급여량이 권장량보다 적습니다. 건강 상태를 살펴보세요.';
    }
    return '현재 급여가 적정합니다. 다음 주문 일정을 계획해 보세요.';
  }

  String get formattedPurchaseDate => _formatDate(purchaseDate);
  String get formattedExpectedEndDate => _formatDate(expectedEndDate);

  static String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'petName': petName,
      'category': category,
      'itemName': itemName,
      'weight': weight,
      'remain': remain,
      'daily': daily,
      'unit': unit,
      'memo': memo,
      'purchaseDate': purchaseDate.toIso8601String(),
    };
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      petName: json['petName'] as String,
      category: json['category'] as String,
      itemName: json['itemName'] as String,
      weight: (json['weight'] as num).toDouble(),
      remain: (json['remain'] as num).toDouble(),
      daily: (json['daily'] as num).toDouble(),
      unit: json['unit'] as String,
      memo: json['memo'] as String,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
    );
  }
}

class DogFoodHomePage extends StatefulWidget {
  const DogFoodHomePage({super.key});

  @override
  State<DogFoodHomePage> createState() => _DogFoodHomePageState();
}

class _DogFoodHomePageState extends State<DogFoodHomePage> {
  static const storageKey = 'dog_food_items';

  final List<FeedItem> _items = [];
  int _selectedTab = 0;
  int? _editingIndex;

  final petNameController = TextEditingController();
  final itemNameController = TextEditingController();
  final weightController = TextEditingController();
  final remainController = TextEditingController();
  final dailyController = TextEditingController();
  final memoController = TextEditingController();

  String _selectedCategory = '주사료';
  String _selectedUnit = 'g';
  DateTime _purchaseDate = DateTime.now();

  final categoryLabels = ['주사료', '간식', '영양제', '습식', '기타'];
  final unitLabels = ['g', '개', '캡슐', '봉', '캔'];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    if (stored != null) {
      final decoded = jsonDecode(stored) as List<dynamic>;
      setState(() {
        _items.clear();
        _items.addAll(decoded.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)));
      });
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1200)),
    );
  }

  bool _validateInput() {
    if (petNameController.text.trim().isEmpty) {
      _showMessage('강아지 이름을 입력해 주세요.');
      return false;
    }
    if (itemNameController.text.trim().isEmpty) {
      _showMessage('품목명을 입력해 주세요.');
      return false;
    }
    final remain = double.tryParse(remainController.text.trim()) ?? 0;
    final daily = double.tryParse(dailyController.text.trim()) ?? 0;
    final weight = double.tryParse(weightController.text.trim()) ?? 0;
    if (weight <= 0) {
      _showMessage('몸무게를 입력해 주세요.');
      return false;
    }
    if (remain <= 0) {
      _showMessage('남은 양은 0보다 커야 합니다.');
      return false;
    }
    if (daily <= 0) {
      _showMessage('하루 사용량은 0보다 커야 합니다.');
      return false;
    }
    return true;
  }

  void _resetForm() {
    petNameController.clear();
    itemNameController.clear();
    weightController.clear();
    remainController.clear();
    dailyController.clear();
    memoController.clear();
    _selectedCategory = '주사료';
    _selectedUnit = 'g';
    _purchaseDate = DateTime.now();
    _editingIndex = null;
  }

  Future<void> _saveForm() async {
    if (!_validateInput()) return;

    final item = FeedItem(
      petName: petNameController.text.trim(),
      category: _selectedCategory,
      itemName: itemNameController.text.trim(),
      weight: double.parse(weightController.text.trim()),
      remain: double.parse(remainController.text.trim()),
      daily: double.parse(dailyController.text.trim()),
      unit: _selectedUnit,
      memo: memoController.text.trim(),
      purchaseDate: _purchaseDate,
    );

    setState(() {
      if (_editingIndex != null) {
        _items[_editingIndex!] = item;
        _showMessage('기록이 수정되었습니다.');
      } else {
        _items.add(item);
        _showMessage('기록이 저장되었습니다.');
      }
      _resetForm();
      _selectedTab = 0;
    });

    await _saveItems();
  }

  Future<void> _selectPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  void _editItem(int index) {
    final item = _items[index];
    setState(() {
      _editingIndex = index;
      petNameController.text = item.petName;
      itemNameController.text = item.itemName;
      weightController.text = item.weight.toStringAsFixed(1);
      remainController.text = item.remain.toStringAsFixed(0);
      dailyController.text = item.daily.toStringAsFixed(0);
      memoController.text = item.memo;
      _selectedCategory = item.category;
      _selectedUnit = item.unit;
      _purchaseDate = item.purchaseDate;
      _selectedTab = 1;
    });
  }

  Future<void> _deleteItem(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('이 기록을 삭제하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        );
      },
    );
    if (result == true) {
      setState(() {
        _items.removeAt(index);
      });
      await _saveItems();
      _showMessage('기록이 삭제되었습니다.');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  int _countStatus(String status) {
    return _items.where((item) => item.stockStatus == status).length;
  }

  List<FeedItem> get _sortedItems {
    final copy = [..._items];
    copy.sort((a, b) => a.remainDays.compareTo(b.remainDays));
    return copy;
  }

  Widget pageShell(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: child,
        ),
      ),
    );
  }

  Widget homeScreen() {
    final soonest = _sortedItems.isNotEmpty ? _sortedItems.first : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('무무 급여 재고 현황', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('사료·영양제·간식 소진일을 예측해요', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xffeef8ec),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text('무', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xff2f9b67))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('무무', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${_items.isNotEmpty ? _items.first.petName : '강아지'} · 재고 상태', style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xffeef8ec),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('로컬 저장됨', style: TextStyle(color: Color(0xff2f9b67))),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge('부족', _countStatus('부족'), const Color(0xfff6e5e3)),
              const SizedBox(width: 10),
              _statusBadge('주의', _countStatus('주의'), const Color(0xfff7eddc)),
              const SizedBox(width: 10),
              _statusBadge('충분', _countStatus('충분'), const Color(0xffe8f5ec)),
            ],
          ),
          const SizedBox(height: 22),
          const Text('소진 예정 빠른 순', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (soonest != null) _soonestCard(soonest) else _emptyStateCard(),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, int count, Color background) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _soonestCard(FeedItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: item.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(item.category, style: TextStyle(color: item.statusColor, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: item.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(item.stockStatus, style: TextStyle(color: item.statusColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(item.itemName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('남은 양 ${item.remain.toStringAsFixed(0)}${item.unit} · 하루 ${item.daily.toStringAsFixed(0)}${item.unit}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Text('${item.remainDaysRounded}일 남음', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: item.statusColor)),
          const SizedBox(height: 8),
          Text('예상 소진일 ${item.formattedExpectedEndDate}', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _emptyStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('등록된 품목이 없습니다. 먼저 급여 품목을 등록해 주세요.', style: TextStyle(color: Colors.black54)),
    );
  }

  Widget registerScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('급여 품목 등록', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('무무가 먹는 모든 것을 관리해요', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffeef7ee),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text('주사료뿐 아니라 영양제, 간식, 습식캔도 등록할 수 있어요. 단위와 하루 사용량 기준으로 소진일을 계산합니다.'),
          ),
          const SizedBox(height: 20),
          const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categoryLabels.map((category) {
              final selected = _selectedCategory == category;
              return ChoiceChip(
                label: Text(category),
                selected: selected,
                selectedColor: const Color(0xff2f9b67),
                backgroundColor: const Color(0xfff1f1f1),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: petNameController,
            decoration: const InputDecoration(labelText: '강아지 이름', hintText: '예: 무무'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: itemNameController,
            decoration: const InputDecoration(labelText: '품목명', hintText: '예: 로얄캐닌 미니 어덜트'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '몸무게 (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  items: unitLabels.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedUnit = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: '단위'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: remainController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '남은 양'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: dailyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '하루 사용량'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _selectPurchaseDate,
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  labelText: '구매일',
                  hintText: _formatDate(_purchaseDate),
                  suffixIcon: const Icon(Icons.calendar_month),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: memoController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '메모', hintText: '예: 아침 75g, 저녁 75g 나눠 급여'),
          ),
          const SizedBox(height: 24),
          _previewResultCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff2f9b67), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _saveForm,
              child: Text(_editingIndex == null ? '로컬에 저장하기' : '수정 내용 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewResultCard() {
    final weight = double.tryParse(weightController.text.trim()) ?? 0;
    final remain = double.tryParse(remainController.text.trim()) ?? 0;
    final daily = double.tryParse(dailyController.text.trim()) ?? 0;

    if (weight <= 0 || remain <= 0 || daily <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Text('입력값을 채우면 실시간 예측 결과를 보여줍니다.', style: TextStyle(color: Colors.black54)),
      );
    }

    final item = FeedItem(
      petName: petNameController.text.trim().isEmpty ? '강아지' : petNameController.text.trim(),
      category: _selectedCategory,
      itemName: itemNameController.text.trim().isEmpty ? '등록할 품목' : itemNameController.text.trim(),
      weight: weight,
      remain: remain,
      daily: daily,
      unit: _selectedUnit,
      memo: memoController.text.trim(),
      purchaseDate: _purchaseDate,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('저장 전 예측 결과', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _resultRow('남은 일수', '${item.remainDaysRounded}일'),
          _resultRow('예상 소진일', item.formattedExpectedEndDate),
          _resultRow('재고 상태', item.stockStatus),
          _resultRow('권장 급여량', '${item.recommendedDaily.toStringAsFixed(0)}g'),
          _resultRow('현재 급여량', '${item.daily.toStringAsFixed(0)}${item.unit}'),
          _resultRow('급여 적정성', item.feedingAssessment),
          const SizedBox(height: 12),
          Text(item.managementComment, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget recordScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('저장된 기록 목록', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('등록한 품목을 수정하거나 삭제할 수 있습니다.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Expanded(
            child: _items.isEmpty
                ? _emptyStateCard()
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _recordCard(item, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(FeedItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.itemName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: item.statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(item.stockStatus, style: TextStyle(color: item.statusColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${item.category} · ${item.petName}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('남은 ${item.remain.toStringAsFixed(0)}${item.unit} · 하루 ${item.daily.toStringAsFixed(0)}${item.unit}', style: const TextStyle(color: Colors.black54))),
              Text('${item.remainDaysRounded}일 남음', style: TextStyle(fontWeight: FontWeight.bold, color: item.statusColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text('예상 소진일 ${item.formattedExpectedEndDate}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Text('권장 ${item.recommendedDaily.toStringAsFixed(0)}g · 현재 ${item.daily.toStringAsFixed(0)}${item.unit} · ${item.feedingAssessment}', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 12),
          Text(item.managementComment, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _editItem(index),
                icon: const Icon(Icons.edit, color: Color(0xff2f9b67)),
                label: const Text('수정', style: TextStyle(color: Color(0xff2f9b67))),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _deleteItem(index),
                icon: const Icon(Icons.delete, color: Color(0xffd9534f)),
                label: const Text('삭제', style: TextStyle(color: Color(0xffd9534f))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget profileScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('앱 정보', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('본 프로젝트는 반려견 보호자가 사료, 간식, 영양제 등의 재고를 효율적으로 관리할 수 있도록 돕는 웹 기반 관리 시스템입니다.'),
          SizedBox(height: 12),
          Text('남은 양과 하루 사용량을 기반으로 남은 일수와 예상 소진일을 계산하고, 재고 상태를 부족/주의/충분으로 분류합니다.'),
          SizedBox(height: 12),
          Text('또한 반려견의 몸무게 기준 권장 급여량과 현재 급여량을 비교하여 급여 적정성을 분석함으로써 단순 재고 계산기를 넘어 반려견 건강 관리 기능까지 포함하도록 설계되었습니다.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pageShell(
        IndexedStack(
          index: _selectedTab,
          children: [homeScreen(), registerScreen(), recordScreen(), profileScreen()],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff2f9b67),
        onPressed: () {
          setState(() {
            _selectedTab = 1;
          });
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        backgroundColor: const Color(0xfffaf4e8),
        selectedItemColor: const Color(0xff2f9b67),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: '등록'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '기록'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: '앱 정보'),
        ],
      ),
    );
  }
}
