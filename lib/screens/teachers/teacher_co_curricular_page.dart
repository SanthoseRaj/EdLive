import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:school_app/models/co_curricular_stat.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';

import '/providers/co_curricular_provider.dart';
import 'teacher_co_curricular_addpage.dart';

class CoCurricularActivitiesPage extends StatelessWidget {
  const CoCurricularActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CoCurricularProvider()..fetchStats(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: TeacherAppBar(),
            drawer: const MenuDrawer(),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFFDBD88A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                '< Back',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final result =
                                    await Navigator.push<
                                      CoCurricularPageResult
                                    >(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddCoCurricularActivityPage(),
                                      ),
                                    );

                                if (result?.didChange == true &&
                                    context.mounted) {
                                  final provider = context
                                      .read<CoCurricularProvider>();
                                  await provider.fetchStats();

                                  final latestAddedStat =
                                      result?.latestAddedStat;
                                  if (latestAddedStat != null) {
                                    await provider.prioritizeStat(
                                      activityName:
                                          latestAddedStat.activityName,
                                      categoryName:
                                          latestAddedStat.categoryName,
                                      className: latestAddedStat.className,
                                    );
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E3192),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/co_curricular.svg',
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Co curricular activities',
                              style: TextStyle(
                                color: Color(0xFF2E3192),
                                fontWeight: FontWeight.bold,
                                fontSize: 29,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Consumer<CoCurricularProvider>(
                          builder: (context, provider, _) {
                            if (provider.isLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (provider.error != null) {
                              return Center(
                                child: Text('Error: ${provider.error}'),
                              );
                            }
                            if (provider.stats.isEmpty) {
                              return const Center(
                                child: Text('No stats found'),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              itemCount: provider.stats.length,
                              itemBuilder: (context, index) {
                                return _buildStatCard(provider.stats[index]);
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(CoCurricularStat stat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              stat.activityName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E3192),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Category: ${stat.categoryName}",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Class: ${stat.className}",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "Students Enrolled: ${stat.enrollmentCount}",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
