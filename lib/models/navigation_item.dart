import 'package:flutter/material.dart';

enum NavigationItemType {
  dashboard,
  products,
  sales,
  inventory,
  customers,
  reports,
  expenses,
  settings,
}

class NavigationItem {
  final NavigationItemType type;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final int index;

  const NavigationItem({
    required this.type,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.index,
  });

  static const List<NavigationItem> items = [
    NavigationItem(
      type: NavigationItemType.dashboard,
      title: 'Inicio',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      index: 0,
    ),
    NavigationItem(
      type: NavigationItemType.sales,
      title: 'Ventas',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      index: 1,
    ),
    NavigationItem(
      type: NavigationItemType.inventory,
      title: 'Inventario',
      icon: Icons.inventory_outlined,
      selectedIcon: Icons.inventory,
      index: 2,
    ),
    NavigationItem(
      type: NavigationItemType.customers,
      title: 'Clientes',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      index: 3,
    ),
    NavigationItem(
      type: NavigationItemType.reports,
      title: 'Reportes',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      index: 4,
    ),
    NavigationItem(
      type: NavigationItemType.expenses,
      title: 'Gastos',
      icon: Icons.money_off_outlined,
      selectedIcon: Icons.money_off,
      index: 5,
    ),
    NavigationItem(
      type: NavigationItemType.settings,
      title: 'Configuración',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      index: 6,
    ),
  ];

  static NavigationItem fromType(NavigationItemType type) {
    return items.firstWhere((item) => item.type == type);
  }

  static NavigationItem fromIndex(int index) {
    return items.firstWhere((item) => item.index == index);
  }
}
