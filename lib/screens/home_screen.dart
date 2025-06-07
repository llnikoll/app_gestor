import 'package:flutter/material.dart';
import '../models/navigation_item.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'venttas_screen.dart';
import 'inventory_screen.dart';
import 'clientes_screen.dart';
import 'reports_screen.dart';
import 'gastos_screen.dart';
import 'settings_screen.dart';

/// Widget que asegura que sus hijos tengan restricciones de ancho finitas
class SafeConstraints extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? minWidth;

  const SafeConstraints({
    super.key,
    required this.child,
    this.maxWidth,
    this.minWidth = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;

        // Calcular restricciones seguras para el ancho
        final safeMaxWidth = maxWidth ?? screenSize.width;
        final safeMinWidth = minWidth ?? 0.0;

        // Crear restricciones seguras
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: safeMinWidth,
            maxWidth: safeMaxWidth,
          ),
          child: child,
        );
      },
    );
  }
}

// Versión simplificada del HomeScreen
// para resolver el error debugFrameWasSentToEngine

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();

  // Método estático para acceder al estado desde cualquier lugar
  static HomeScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeScreenState>();
  }
}

class _HomeScreenContent extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<Widget> screens;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const _HomeScreenContent({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.screens,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(NavigationItem.fromIndex(selectedIndex).title),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildDrawer(context, selectedIndex, onItemTapped),
      body: SafeConstraints(
        maxWidth: screenSize.width,
        child: IndexedStack(
          index: selectedIndex.clamp(0, screens.length - 1),
          children: screens,
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    int selectedIndex,
    ValueChanged<int> onItemTapped,
  ) {
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
          for (final item in NavigationItem.items)
            ListTile(
              leading: Icon(
                selectedIndex == item.index ? item.selectedIcon : item.icon,
                color: selectedIndex == item.index
                    ? Theme.of(context).primaryColor
                    : null,
              ),
              title: Text(item.title),
              selected: selectedIndex == item.index,
              selectedTileColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              onTap: () {
                onItemTapped(item.index);
                Navigator.pop(context);
              },
            ),
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
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final List<Widget> _screens;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeScreens();
      }
    });
  }

  void _initializeScreens() {
    if (_isInitialized) return;

    _screens = [
      const DashboardScreen(),
      const SalesScreen(),
      const InventoryScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
      const GastosScreen(),
      const SettingsScreen(),
    ];

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void onItemTapped(int index) {
    if (index >= 0 && index < _screens.length && mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildMobileLayout() {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 0.0,
        maxWidth: double.infinity,
      ),
      child: _HomeScreenContent(
        selectedIndex: _selectedIndex.clamp(0, _screens.length - 1),
        onItemTapped: onItemTapped,
        screens: _screens,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          _buildDesktopNavigationRail(),
          // Contenido principal con ancho restringido
          Expanded(
            child: SafeConstraints(
              maxWidth:
                  screenSize.width -
                  100, // Dejamos espacio para el rail de navegación
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ),
        ],
      ),
    );
  }

  // Drawer is now part of _HomeScreenContent

  Widget _buildDesktopNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: onItemTapped,
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
    // Verificación simple de inicialización
    if (!_isInitialized || _screens.isEmpty) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    // Asegurarse de que el índice esté dentro de los límites
    final safeIndex = _selectedIndex.clamp(0, _screens.length - 1);
    if (_selectedIndex != safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedIndex = safeIndex);
        }
      });
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    // Layout simple sin widgets complejos
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth < 600
              ? _buildMobileLayout()
              : _buildDesktopLayout();
        },
      ),
    );
  }
}
