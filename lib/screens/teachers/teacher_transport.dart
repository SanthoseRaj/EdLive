import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_menu_drawer.dart';
import '/../models/transport_model.dart';
import '/../services/transport_service.dart';

class TransportPage extends StatefulWidget {
  final int staffId;
  // final String academicYear;

  const TransportPage({super.key, required this.staffId});

  @override
  _TransportPageState createState() => _TransportPageState();
}

class _TransportPageState extends State<TransportPage> {
  late Future<Transport?> transportFuture;

  @override
  void initState() {
    super.initState();
    transportFuture = TransportService().getTransportDetails(widget.staffId);
  }

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
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, color: Colors.black)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 16, color: Colors.black)),
                  ],
                ),
                Text(value2, style: const TextStyle(fontSize: 16, color: Colors.black)),
              ],
            ),
    );
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFCCCCFF), // full screen background
    appBar: TeacherAppBar(),
    drawer: MenuDrawer(),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Transport?>(
        future: transportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No transport data found.'));
          }

          final transport = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  '<Back',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E3192),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/transport.svg',
                      height: 20,
                      width: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Transport',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              buildInfoRow("Bus Number", transport.busNumber),
              buildInfoRow("Route", transport.routeName),
              buildInfoRow("Stop", transport.stopName),
              buildInfoRow("Arrival Time", transport.arrivalTime),
              buildInfoRow("Driver", transport.driverName,
                  value2: transport.driverContact),
              if (transport.managerName != null)
                buildInfoRow("Manager", transport.managerName!,
                    value2: transport.managerContact),
            ],
          );
        },
      ),
    ),
  );
}

}