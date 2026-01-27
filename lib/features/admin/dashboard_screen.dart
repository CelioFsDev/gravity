import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/viewmodels/dashboard_viewmodel.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Relatórios e análises',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    // Seed data for verification
                    ref.read(dashboardViewModelProvider.notifier).seedData();
                  }, 
                  child: const Text('Seed Data (Dev)')
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // content
            dashboardState.when(
              data: (data) => _buildDashboardContent(context, data),
              error: (e, s) => Center(child: Text('Error: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardState data) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final kpiCards = [
      _buildKpiCard(context, 'Faturamento total', currencyFormat.format(data.totalRevenue), Icons.attach_money, Colors.green),
      _buildKpiCard(context, 'Ticket médio', currencyFormat.format(data.averageTicket), Icons.receipt, Colors.blue),
      _buildKpiCard(context, 'Pedidos confirmados', data.confirmedOrdersCount.toString(), Icons.check_circle, Colors.orange),
      _buildKpiCard(context, 'Pedidos pendentes', data.pendingOrdersCount.toString(), Icons.pending, Colors.red),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var card in kpiCards)
                  SizedBox(
                    width: isWide ? cardWidth : constraints.maxWidth,
                    child: card,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildChartBox(
                          context,
                          title: 'Faturamento por dia',
                          child: _buildRevenueChart(data.weeklyRevenue),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _buildChartBox(
                          context,
                          title: 'Pedidos por status',
                          child: _buildStatusChart(data.ordersByStatus),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildChartBox(
                        context,
                        title: 'Faturamento por dia',
                        child: SizedBox(height: 260, child: _buildRevenueChart(data.weeklyRevenue)),
                      ),
                      const SizedBox(height: 24),
                      _buildChartBox(
                        context,
                        title: 'Pedidos por status',
                        child: SizedBox(height: 260, child: _buildStatusChart(data.ordersByStatus)),
                      ),
                    ],
                  ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey.shade600)),
              Icon(icon, color: color),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildChartBox(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
  
  Widget _buildRevenueChart(Map<int, double> weeklyRevenue) {
    if (weeklyRevenue.isEmpty) {
        return const Center(child: Text('Sem dados'));
    }
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']; // Short Portuguese weekdays
                // weekday 1-7 (Mon-Sun) -> index 1-7. let's adjust map.
                // DateTime.weekday: 1=Mon, 7=Sun.
                // List index: 0=D? No.
                // Let's just return simple text.
                return Text(days[(value.toInt() - 1) % 7]);
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: weeklyRevenue.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
             belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(Map<OrderStatus, int> ordersByStatus) {
      if (ordersByStatus.isEmpty) {
          return const Center(child: Text('Sem dados'));
      }
      return PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 40,
          sections: ordersByStatus.entries.map((e) {
             final color = _getStatusColor(e.key);
             return PieChartSectionData(
               color: color,
               value: e.value.toDouble(),
               title: '${e.value}',
               radius: 50,
               titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
             );
          }).toList(),
        ),
      );
  }
  
  Color _getStatusColor(OrderStatus status) {
    switch(status) {
      case OrderStatus.pending: return Colors.orange;
      case OrderStatus.confirmed: return Colors.blue;
      case OrderStatus.paid: return Colors.indigo;
      case OrderStatus.shipped: return Colors.purple;
      case OrderStatus.delivered: return Colors.green;
      case OrderStatus.cancelled: return Colors.red;
    }
  }
}
