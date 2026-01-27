import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/order.dart';
import 'package:gravity/models/order_status.dart';
import 'package:gravity/viewmodels/orders_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(ordersViewModelProvider);

    return Scaffold(
      body: ordersState.when(
        data: (state) => _buildContent(context, ref, state),
        error: (e, s) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, OrdersState state) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    final today = DateTime.now();
    final ordersToday = state.allOrders.where((o) {
      return o.createdAt.year == today.year &&
          o.createdAt.month == today.month &&
          o.createdAt.day == today.day;
    }).length;

    final totalOrders = state.allOrders.length;

    final revenue = state.allOrders
        .where((o) => _countsTowardRevenue(o.status))
        .fold(0.0, (sum, o) => sum + o.total);

    final avgTicket = totalOrders == 0 ? 0.0 : revenue / totalOrders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Gestao de pedidos',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              final cardWidth = isWide
                  ? (constraints.maxWidth - 48) / 4
                  : constraints.maxWidth;
              final cards = [
                _buildKpiCard(
                  context,
                  'Pedidos hoje',
                  ordersToday.toString(),
                  Icons.today,
                  Colors.blue,
                ),
                _buildKpiCard(
                  context,
                  'Total pedidos',
                  totalOrders.toString(),
                  Icons.list_alt,
                  Colors.green,
                ),
                _buildKpiCard(
                  context,
                  'Faturamento',
                  currencyFormat.format(revenue),
                  Icons.attach_money,
                  Colors.orange,
                ),
                _buildKpiCard(
                  context,
                  'Ticket medio',
                  currencyFormat.format(avgTicket),
                  Icons.insights,
                  Colors.purple,
                ),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: cards
                    .map((card) => SizedBox(width: cardWidth, child: card))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por ID, nome, telefone...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => ref
                        .read(ordersViewModelProvider.notifier)
                        .setSearchQuery(val),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButton<OrderStatus?>(
                    isExpanded: true,
                    value: state.filterStatus,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<OrderStatus?>(
                        value: null,
                        child: Text('Todos status'),
                      ),
                      ...OrderStatus.values.map(
                        (s) => DropdownMenuItem<OrderStatus?>(
                          value: s,
                          child: Text(_statusLabel(s)),
                        ),
                      ),
                    ],
                    onChanged: (val) => ref
                        .read(ordersViewModelProvider.notifier)
                        .setFilterStatus(val),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateRange(context, ref, state),
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateRangeLabel(state.dateRange)),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButton<SortOption>(
                    isExpanded: true,
                    value: state.sortOption,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: SortOption.recent,
                        child: Text('Mais recentes'),
                      ),
                      DropdownMenuItem(
                        value: SortOption.oldest,
                        child: Text('Mais antigos'),
                      ),
                      DropdownMenuItem(
                        value: SortOption.highValue,
                        child: Text('Maior valor'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(ordersViewModelProvider.notifier)
                            .setSortOption(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (state.filteredOrders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nenhum pedido encontrado.'),
              ),
            ),
          ...state.filteredOrders.map(
            (order) => _buildOrderTile(context, ref, order),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.1),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, WidgetRef ref, Order order) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.clientName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              currencyFormat.format(order.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormat.format(order.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _statusBadge(order.status),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text(
                  'Itens do Pedido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1),
                  },
                  children: [
                    const TableRow(
                      children: [
                        Text('Produto', style: TextStyle(color: Colors.grey)),
                        Text('Tamanho', style: TextStyle(color: Colors.grey)),
                        Text('Qtd', style: TextStyle(color: Colors.grey)),
                        Text('Preco', style: TextStyle(color: Colors.grey)),
                        Text('Total', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    ...order.items.map(
                      (item) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName),
                                Text(
                                  item.productReference,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(item.selectedSize ?? '-'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(item.quantity.toString()),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(currencyFormat.format(item.unitPrice)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(currencyFormat.format(item.total)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<OrderStatus>(
                      value: order.status,
                      items: OrderStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(_statusLabel(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          ref
                              .read(ordersViewModelProvider.notifier)
                              .updateStatus(order.id, newStatus);
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _launchWhatsApp(order),
                      icon: const Icon(Icons.chat),
                      label: const Text('Conversar no WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(OrderStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pendente';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.paid:
        return 'Pago';
      case OrderStatus.shipped:
        return 'Enviado';
      case OrderStatus.delivered:
        return 'Entregue';
      case OrderStatus.cancelled:
        return 'Cancelado';
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.paid:
        return Colors.green;
      case OrderStatus.shipped:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.teal;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  bool _countsTowardRevenue(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
      case OrderStatus.paid:
      case OrderStatus.shipped:
      case OrderStatus.delivered:
        return true;
      case OrderStatus.pending:
      case OrderStatus.cancelled:
        return false;
    }
  }

  String _dateRangeLabel(DateTimeRange? range) {
    if (range == null) return 'Periodo';
    final start = DateFormat('dd/MM').format(range.start);
    final end = DateFormat('dd/MM').format(range.end);
    return '$start - $end';
  }

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    OrdersState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: state.dateRange,
    );
    if (picked != null) {
      ref.read(ordersViewModelProvider.notifier).setDateRange(picked);
    }
  }

  Future<void> _launchWhatsApp(Order order) async {
    final message = Uri.encodeComponent(
      'Ola ${order.clientName}, sobre o seu pedido #${order.id}...',
    );
    final url = Uri.parse('https://wa.me/${order.clientPhone}?text=$message');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }
}
