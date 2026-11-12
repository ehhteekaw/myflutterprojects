import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift_lib hide Column;
import '../../core/database.dart';
import 'product_provider.dart';
import 'student_provider.dart';

class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen> {
  // ================= CONTROLLER & PAGINATION STATE =================
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  final int _rowsPerPage = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentStreamProvider);
    final searchQuery = ref.watch(studentSearchQueryProvider);
    final db = ref.watch(databaseProvider);

    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student ID Card & Balance Management'),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= SEARCH & ACTION BAR =================
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Student ID or Name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(studentSearchQueryProvider.notifier)
                                    .state = '';
                                setState(() {
                                  _currentPage = 1;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      ref.read(studentSearchQueryProvider.notifier).state = val;
                      setState(() {
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add New Student'),
                  onPressed: () => _showStudentDialog(context, db),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Showing info header
            studentsAsync.when(
              data: (allStudents) {
                final query = searchQuery.toLowerCase().trim();
                final filteredList = allStudents.where((s) {
                  return query.isEmpty ||
                      s.studentIdNumber.toLowerCase().contains(query) ||
                      s.name.toLowerCase().contains(query);
                }).toList();

                final totalStudents = filteredList.length;
                final totalPages = (totalStudents / _rowsPerPage).ceil();

                if (_currentPage > totalPages && totalPages > 0) {
                  _currentPage = totalPages;
                }

                final startIndex = (_currentPage - 1) * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage > totalStudents)
                    ? totalStudents
                    : startIndex + _rowsPerPage;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Student List Table',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (totalStudents > 0)
                      Text(
                        'Showing ${startIndex + 1}-$endIndex of $totalStudents students',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),

            // ================= STUDENTS TABLE & PAGINATION =================
            Expanded(
              child: studentsAsync.when(
                data: (allStudents) {
                  final query = searchQuery.toLowerCase().trim();
                  final filteredList = allStudents.where((s) {
                    return query.isEmpty ||
                        s.studentIdNumber.toLowerCase().contains(query) ||
                        s.name.toLowerCase().contains(query);
                  }).toList();

                  if (filteredList.isEmpty) {
                    return const Center(
                      child: Text('No students found.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final totalStudents = filteredList.length;
                  final totalPages = (totalStudents / _rowsPerPage).ceil();

                  if (_currentPage > totalPages && totalPages > 0) {
                    _currentPage = totalPages;
                  }

                  final startIndex = (_currentPage - 1) * _rowsPerPage;
                  final endIndex = (startIndex + _rowsPerPage > totalStudents)
                      ? totalStudents
                      : startIndex + _rowsPerPage;

                  final paginatedStudents = totalStudents > 0
                      ? filteredList.sublist(startIndex, endIndex)
                      : <Student>[];

                  return Card(
                    elevation: 1,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                        MediaQuery.of(context).size.width - 40,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        Colors.grey.shade100),
                                    columnSpacing: 16,
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 56,
                                    columns: const [
                                      DataColumn(
                                          label: Text('No.',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      DataColumn(
                                          label: Text('Card ID / Student ID',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      DataColumn(
                                          label: Text('Student Name',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      DataColumn(
                                          label: Text('Class / Grade',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      DataColumn(
                                          label: Text('Current Balance',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      DataColumn(
                                          label: Text('Actions',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ],
                                    rows: paginatedStudents
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final student = entry.value;
                                      final dbId = student.id;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text('$dbId',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey))),
                                          DataCell(
                                            Chip(
                                              label: Text(
                                                  student.studentIdNumber,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12)),
                                              backgroundColor:
                                                  Colors.blue.shade50,
                                            ),
                                          ),
                                          DataCell(Text(student.name,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600))),
                                          DataCell(Text(
                                              student.gradeOrClass ?? '-')),
                                          DataCell(
                                            Text(
                                              '${student.balance.toStringAsFixed(0)} MMK',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: student.balance < 1000
                                                    ? Colors.red
                                                    : Colors.green,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Top-Up Button
                                                ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green.shade600,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.add_card_outlined,
                                                      size: 16),
                                                  label: const Text('Top-Up'),
                                                  onPressed: () =>
                                                      _showTopUpDialog(
                                                          context, db, student),
                                                ),
                                                const SizedBox(width: 6),
                                                // 👉 Withdraw Button (NEW)
                                                ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.orange.shade700,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                  ),
                                                  icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      size: 16),
                                                  label: const Text('Withdraw'),
                                                  onPressed: () =>
                                                      _showWithdrawDialog(
                                                          context, db, student),
                                                ),
                                                const SizedBox(width: 6),
                                                // Edit Button
                                                IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      color: Colors.blue,
                                                      size: 20),
                                                  tooltip: 'Edit Student',
                                                  onPressed: () =>
                                                      _showStudentDialog(
                                                          context, db,
                                                          existingStudent:
                                                              student),
                                                ),
                                                // Delete Button
                                                IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.red,
                                                      size: 20),
                                                  tooltip: 'Delete Student',
                                                  onPressed: () =>
                                                      _showDeleteConfirmation(
                                                          context, db, student),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ================= PAGINATION CONTROLLER BAR =================
                        if (totalPages > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Page $_currentPage of $totalPages',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: _currentPage > 1
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                      tooltip: 'Previous Page',
                                    ),
                                    const SizedBox(width: 8),
                                    ...List.generate(totalPages, (index) {
                                      final pageNum = index + 1;
                                      final isSelected =
                                          pageNum == _currentPage;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 2.0),
                                        child: InkWell(
                                          onTap: () => setState(
                                              () => _currentPage = pageNum),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$pageNum',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: _currentPage < totalPages
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                      tooltip: 'Next Page',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                    child: Text('Database Error: $err',
                        style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= ADD / EDIT STUDENT DIALOG =================
  void _showStudentDialog(BuildContext context, AppDatabase db,
      {Student? existingStudent}) {
    final idController =
        TextEditingController(text: existingStudent?.studentIdNumber ?? '');
    final nameController =
        TextEditingController(text: existingStudent?.name ?? '');
    final gradeController =
        TextEditingController(text: existingStudent?.gradeOrClass ?? '');

    final balanceController = TextEditingController(
        text: existingStudent != null
            ? existingStudent.balance.toStringAsFixed(0)
            : '0');

    final focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingStudent == null
            ? 'Add New Student Card'
            : 'Edit Student Details & Balance'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                    labelText: 'Student Card ID / Number (Scan or Type)',
                    border: OutlineInputBorder()),
                enabled: existingStudent == null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: 'Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gradeController,
                decoration: const InputDecoration(
                    labelText: 'Grade / Class (e.g. Grade 10-A)',
                    border: OutlineInputBorder()),
              ),
              if (existingStudent != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Current Balance (MMK) - Direct Edit',
                      border: OutlineInputBorder(),
                      prefixText: 'MMK '),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final idNum = idController.text.trim();
              final name = nameController.text.trim();
              final grade = gradeController.text.trim();
              final newBalance = double.tryParse(balanceController.text) ??
                  (existingStudent?.balance ?? 0.0);

              if (idNum.isNotEmpty && name.isNotEmpty) {
                if (existingStudent == null) {
                  await db.into(db.students).insert(
                        StudentsCompanion.insert(
                          studentIdNumber: idNum,
                          name: name,
                          gradeOrClass: drift_lib.Value(grade),
                          balance: const drift_lib.Value(0.0),
                          createdAt: drift_lib.Value(DateTime.now()),
                        ),
                      );
                } else {
                  await (db.update(db.students)
                        ..where((s) => s.id.equals(existingStudent.id)))
                      .write(
                    StudentsCompanion(
                      name: drift_lib.Value(name),
                      gradeOrClass: drift_lib.Value(grade),
                      balance: drift_lib.Value(newBalance),
                    ),
                  );
                }
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ================= TOP-UP MONEY DIALOG =================
  void _showTopUpDialog(BuildContext context, AppDatabase db, Student student) {
    final amountController = TextEditingController();
    final topUpFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      topUpFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Top-Up Balance: ${student.name}'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card ID: ${student.studentIdNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Current Balance: ${student.balance.toStringAsFixed(0)} MMK',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                focusNode: topUpFocusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Top-Up Amount (MMK)',
                  border: OutlineInputBorder(),
                  prefixText: 'MMK ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final addAmount = double.tryParse(amountController.text) ?? 0.0;
              if (addAmount > 0) {
                final newBalance = student.balance + addAmount;
                await (db.update(db.students)
                      ..where((s) => s.id.equals(student.id)))
                    .write(
                  StudentsCompanion(balance: drift_lib.Value(newBalance)),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Confirm Top-Up'),
          ),
        ],
      ),
    );
  }

  // ================= WITHDRAW MONEY DIALOG (NEW) =================
  void _showWithdrawDialog(
      BuildContext context, AppDatabase db, Student student) {
    final amountController = TextEditingController();
    final withdrawFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      withdrawFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw / Deduct Balance: ${student.name}'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card ID: ${student.studentIdNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Current Balance: ${student.balance.toStringAsFixed(0)} MMK',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                focusNode: withdrawFocusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Withdraw Amount (MMK)',
                  border: OutlineInputBorder(),
                  prefixText: 'MMK ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white),
            onPressed: () async {
              final deductAmount =
                  double.tryParse(amountController.text) ?? 0.0;
              if (deductAmount > 0) {
                if (deductAmount > student.balance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Error: Withdraw amount exceeds current balance!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newBalance = student.balance - deductAmount;
                await (db.update(db.students)
                      ..where((s) => s.id.equals(student.id)))
                    .write(
                  StudentsCompanion(balance: drift_lib.Value(newBalance)),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Confirm Withdraw'),
          ),
        ],
      ),
    );
  }

  // ================= DELETE STUDENT CONFIRMATION DIALOG =================
  void _showDeleteConfirmation(
      BuildContext context, AppDatabase db, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student Card'),
        content: Text(
            'Are you sure you want to delete ${student.name} (${student.studentIdNumber})? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await (db.delete(db.students)
                    ..where((s) => s.id.equals(student.id)))
                  .go();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
