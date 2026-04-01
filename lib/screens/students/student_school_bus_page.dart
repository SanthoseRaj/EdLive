import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import '../../services/student_schoolbus.dart';
import '../../models/student_schoolbus.dart';

class StudentSchoolBusPage extends StatefulWidget {
  const StudentSchoolBusPage({super.key});

  @override
  State<StudentSchoolBusPage> createState() => _StudentSchoolBusPageState();
}

class _StudentSchoolBusPageState extends State<StudentSchoolBusPage> {
  Transport? transport;
  bool isLoading = true;
  String errorMsg = "";

  @override
  void initState() {
    super.initState();
    _loadTransport();
  }

  Future<void> _loadTransport() async {
    try {
      final data = await TransportService.fetchStudentTransport(
        18,
        academicYear: AppConfig.academicYear,
      );
      setState(() {
        transport = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = e.toString();
        isLoading = false;
      });
    }
  }

  // Reusable info row
  Widget buildInfoRow(String label, String value, {String? value2}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: value2 == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
                Text(
                  value2,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      body: Container(
        color: const Color(0xFFDAD9FF),
        width: double.infinity,
        height: double.infinity,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMsg.isNotEmpty
            ? Center(child: Text(errorMsg))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔙 Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        '< Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 🚍 Icon + Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3192),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/transport.svg',
                            height: 20,
                            width: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'School Bus',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E3192),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // API Data
                    buildInfoRow("Bus Number", transport!.busNumber),
                    buildInfoRow("Pick-up Time", transport!.arrivalTime),
                    buildInfoRow("Pick-up Location", transport!.stopName),
                    buildInfoRow(
                      "Driver",
                      transport!.driverName,
                      value2: transport!.driverContact,
                    ),
                    buildInfoRow(
                      "Transport Manager",
                      transport!.managerName ?? "-",
                      value2: transport!.managerContact ?? "-",
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
