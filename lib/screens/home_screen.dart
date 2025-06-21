import 'package:flutter/material.dart';
import '../models/navigation_item.dart';
import 'dashboard_screen.dart';
import 'ventas_screen.dart';
import 'inventory_screen.dart';
import 'clientes_screen.dart';
import 'reports_screen.dart';
import 'gastos_screen.dart';
import 'settings_screen.dart';

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
        final screenSize = MediaQuery
            .of(context)
            .size;
        final safeMaxWidth = maxWidth ?? screenSize.width;
        final safeMinWidth = minWidth ?? 0.0;
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();

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
    final screenSize = MediaQuery
        .of(context)
        .size;
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(NavigationItem
            .fromIndex(selectedIndex)
            .title),
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

  Widget _buildDrawer(BuildContext context,
      int selectedIndex,
      ValueChanged<int> onItemTapped,) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isWideScreen = screenWidth > 600;

    return SizedBox(
      width: isWideScreen ? screenWidth * 0.25 : screenWidth * 0.7,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme
                  .of(context)
                  .primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.store, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mi Negocio',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin@minegocio.com',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            for (final item in NavigationItem.items)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: selectedIndex == item.index
                      ? Theme
                      .of(context)
                      .primaryColor
                      .withAlpha(26) // alpha 0.1
                      : Colors.transparent,
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    selectedIndex == item.index ? item.selectedIcon : item.icon,
                    color: selectedIndex == item.index
                        ? Theme
                        .of(context)
                        .primaryColor
                        : null,
                    size: 22,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: isWideScreen ? 14 : 13,
                      fontWeight: selectedIndex == item.index
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    onItemTapped(item.index);
                    Navigator.pop(context); // Cierra el drawer
                  },
                ),
              ),
            const Divider(thickness: 1, height: 1, indent: 16, endIndent: 16),
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.logout, size: 22),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/mode_selection',
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
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
      const SalesScreen(), // O VentasScreen si ese es el nombre de tu clase
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

  // Define un método para manejar la lógica de "pop"
  // Devuelve true si el pop debe continuar (cerrar app), false si fue manejado.
  bool _handlePop() {
    if (_selectedIndex != 0) { // Si no estamos en el Dashboard (índice 0)
      onItemTapped(0); // Volver al Dashboard
      return false; // El pop fue manejado, no continuar
    }
    return true; // Estamos en el Dashboard, permitir el pop (cerrar app)
  }

  Widget _buildMobileLayout() {
    return PopScope(
      canPop: _selectedIndex == 0,
      // Solo permite el pop si estamos en Dashboard
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return; // Si el pop ocurrió (porque canPop era true), no hacer nada más
        }
        // Si el pop fue prevenido (porque canPop era false), manejarlo aquí
        _handlePop();
      },
      child: Container(
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
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final screenSize = MediaQuery
        .of(context)
        .size;
    return PopScope(
      canPop: _selectedIndex == 0,
      // Solo permite el pop si estamos en Dashboard
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handlePop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        body: Row(
          children: [
            Container(
              width: 140,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme
                        .of(context)
                        .dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 12,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme
                          .of(context)
                          .primaryColor,
                      child: const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableHeight = constraints.maxHeight;
                        const double itemHeight = 72.0;
                        final totalItemsHeight =
                            NavigationItem.items.length * itemHeight;
                        final needsScroll = totalItemsHeight > availableHeight;

                        if (needsScroll) {
                          return SingleChildScrollView(
                            child: Column(
                              children: NavigationItem.items.map((item) {
                                final isSelected = _selectedIndex == item.index;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Material(
                                    color: isSelected
                                        ? Theme
                                        .of(context)
                                        .primaryColor
                                        .withAlpha(26)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => onItemTapped(item.index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 8,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? item.selectedIcon
                                                  : item.icon,
                                              size: 26,
                                              color: isSelected
                                                  ? Theme
                                                  .of(context)
                                                  .primaryColor
                                                  : null,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? Theme
                                                    .of(context)
                                                    .primaryColor
                                                    : null,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        } else {
                          return NavigationRail(
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: onItemTapped,
                            labelType: NavigationRailLabelType.all,
                            minWidth: 140,
                            minExtendedWidth: 140,
                            groupAlignment: 0.0,
                            leading: const SizedBox(height: 20),
                            trailing: const SizedBox(height: 20),
                            destinations: NavigationItem.items.map((item) {
                              return NavigationRailDestination(
                                icon: Icon(item.icon, size: 26),
                                label: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                selectedIcon: Icon(item.selectedIcon, size: 26),
                              );
                            }).toList(),
                          );
                        }
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: Theme
                              .of(context)
                              .dividerColor,
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/mode_selection',
                              (route) => false,
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.logout, size: 24),
                                SizedBox(height: 6),
                                Text(
                                  'Cerrar Sesión',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SafeConstraints(
                maxWidth: screenSize.width - 100,
                child: IndexedStack(
                  index: _selectedIndex.clamp(0, _screens.length - 1),
                  children: _screens,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _screens.isEmpty) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    final safeIndex = _selectedIndex.clamp(0, _screens.length - 1);
    if (_selectedIndex != safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedIndex = safeIndex);
        }
      });
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
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