import 'package:flutter/material.dart';
import '../models/navigation_item.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'sales_screen.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controladores para cada pantalla
  final List<Widget> _screens = [
    const DashboardScreen(),
    const ProductsScreen(),
    const SalesScreen(),
    const InventoryScreen(),
    const CustomersScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    // Asegurarse de que el índice esté dentro del rango de pantallas disponibles
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(NavigationItem.fromIndex(_selectedIndex).title),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildDrawer(),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          // Menú lateral
          _buildDesktopNavigationRail(),
          // Contenido principal
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mi Negocio',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'admin@minegocio.com',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          ...NavigationItem.items.map((item) {
            return ListTile(
              leading: Icon(
                _selectedIndex == item.index ? item.selectedIcon : item.icon,
                color: _selectedIndex == item.index
                    ? Theme.of(context).primaryColor
                    : null,
              ),
              title: Text(item.title),
              selected: _selectedIndex == item.index,
              selectedTileColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              onTap: () {
                _onItemTapped(item.index);
                Navigator.pop(context);
              },
            );
          }),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              // Cerrar sesión
            },
          ),
        ],
      ),
    );
  }



  Widget _buildDesktopNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      labelType: NavigationRailLabelType.all,
      leading: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.store, color: Colors.white),
          ),
          const SizedBox(height: 16),
        ],
      ),
      trailing: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Salir'),
              horizontalTitleGap: 0,
              minLeadingWidth: 0,
              onTap: () {
                // Cerrar sesión
              },
            ),
          ],
        ),
      ),
      destinations: NavigationItem.items.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.icon),
          label: Text(item.title),
          selectedIcon: Icon(item.selectedIcon),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en un dispositivo móvil o escritorio
    final isMobile = MediaQuery.of(context).size.width < 600;

    return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  }
}
