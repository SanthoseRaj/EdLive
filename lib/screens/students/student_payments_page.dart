import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';

import 'package:school_app/models/student_payment_model.dart';
import 'package:school_app/services/student_payment_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:school_app/config/config.dart';

class StudentPaymentsPage extends StatefulWidget {
  final String studentId;

  const StudentPaymentsPage({Key? key, required this.studentId})
    : super(key: key);

  @override
  State<StudentPaymentsPage> createState() => _StudentPaymentsPageState();
}

class _StudentPaymentsPageState extends State<StudentPaymentsPage> {
  bool isDueSelected = true;
  List<StudentPayment> _payments = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      debugPrint("TOKEN: ${prefs.getString('auth_token')}");
      debugPrint("STUDENT ID: ${prefs.getString('studentId')}");
    });
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception("Missing auth token");
      }

      final payments = await StudentPaymentService().fetchStudentPayments(
        widget.studentId,
      );

      // ✅ Mark only due/overdue payments as viewed automatically
      for (var p in payments) {
        await markPaymentAsViewed(p.studentId, p.feeAssignmentId);
      }

      setState(() {
        _payments = payments;
      });

      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> markPaymentAsViewed(int studentId, int feeAssignmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.post(
      Uri.parse("${AppConfig.baseUrl}/dashboard/viewed?studentId=$studentId"),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"item_type": "payments", "item_id": feeAssignmentId}),
    );

    if (response.statusCode == 200) {
      print("✅ Marked as viewed: $feeAssignmentId");
    } else {
      print("❌ Failed to mark viewed: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC7E59E),
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTabSelector(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _hasError
                            ? const Center(child: Text("Failed to load data."))
                            : isDueSelected
                            ? _buildDueSection()
                            : _buildHistorySection(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              '< Back',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3192),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SvgPicture.asset(
                  'assets/icons/payments.svg',
                  width: 20,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Payments",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => isDueSelected = true),
          child: Column(
            children: [
              Text(
                "Due",
                style: TextStyle(
                  color: isDueSelected ? const Color(0xFF29ABE2) : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              if (isDueSelected)
                Container(height: 3, width: 30, color: const Color(0xFF29ABE2)),
            ],
          ),
        ),
        const SizedBox(width: 40),
        GestureDetector(
          onTap: () => setState(() => isDueSelected = false),
          child: Column(
            children: [
              Text(
                "History",
                style: TextStyle(
                  color: !isDueSelected
                      ? const Color(0xFF29ABE2)
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              if (!isDueSelected)
                Container(height: 3, width: 50, color: const Color(0xFF29ABE2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDueSection() {
    final duePayments = _payments
        .where(
          (p) => p.paymentStatus == "pending" || p.paymentStatus == "overdue",
        )
        .toList();

    if (duePayments.isEmpty) {
      return const Center(child: Text("No due payments found."));
    }

    return ListView.builder(
      itemCount: duePayments.length,
      itemBuilder: (context, index) {
        final payment = duePayments[index];
        final formattedDate =
            payment.dueDate?.toIso8601String().split('T').first ?? "-";

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Due on $formattedDate",
                  style: TextStyle(
                    color: payment.paymentStatus == "overdue"
                        ? Colors.red
                        : const Color(0xFF3D348B),
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Fee: ${payment.feeName}",
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  "Amount: ₹${payment.amount}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    if (payment.upiLink != null) {
                      _showQRDialog(context, payment.upiLink!);
                    }
                  },
                  child: const Text(
                    "Pay",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQRDialog(BuildContext context, String upiLink) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Scan to Pay",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: QrImageView(
                      data: upiLink,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Or pay via link", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      launchUrl(Uri.parse(upiLink));
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Open Payment Link",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistorySection() {
    final paidPayments = _payments
        .where((p) => p.paymentStatus == "paid")
        .toList();

    if (paidPayments.isEmpty) {
      return const Center(child: Text("No payment history available."));
    }

    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(color: Colors.grey, width: 1.2),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFEFEFEF)),
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Payment Info',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Amount',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          ...paidPayments.map((p) {
            final paymentDate = p.paymentDate?.split('T').first ?? '-';
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(p.feeName),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text("₹${p.amount}"),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(paymentDate),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
