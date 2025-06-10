import 'package:flutter/material.dart';
import '../models/navigation_item.dart';
import 'dashboard_screen.dart';
import 'ventas_screen.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen =
        screenWidth > 600; // Consideramos pantalla ancha más de 600px

    return SizedBox(
      width: isWideScreen
          ? screenWidth * 0.25
          : screenWidth * 0.7, // Ajustar ancho según el tamaño de la pantalla
      child: Drawer(
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
                    child: Icon(Icons.store, size: 40, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mi Negocio',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18, // Tamaño de fuente un poco más pequeño
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin@minegocio.com',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      fontSize: 12, // Tamaño de fuente más pequeño
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
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: ListTile(
                  dense: true, // Hace el ListTile más compacto
                  visualDensity:
                      VisualDensity.compact, // Reduce el espacio vertical
                  leading: Icon(
                    selectedIndex == item.index ? item.selectedIcon : item.icon,
                    color: selectedIndex == item.index
                        ? Theme.of(context).primaryColor
                        : null,
                    size: 22, // Tamaño de icono ligeramente más pequeño
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: isWideScreen
                          ? 14
                          : 13, // Tamaño de fuente responsivo
                      fontWeight: selectedIndex == item.index
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    onItemTapped(item.index);
                    Navigator.pop(context);
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
                  // Cerrar sesión
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
          // Navigation Rail Container with custom logout
          Container(
            width: 140, // Aumentado de 100 a 140 para más espacio
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Header con más espacio
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 12,
                  ),
                  child: CircleAvatar(
                    radius: 24, // Aumentado de 16 a 24
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 28, // Aumentado de 18 a 28
                    ),
                  ),
                ),
                // Navigation Rail con scroll si es necesario
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calcular si necesitamos scroll
                      final availableHeight = constraints.maxHeight;
                      final itemHeight = 72.0; // Altura aproximada por item
                      final totalItemsHeight =
                          NavigationItem.items.length * itemHeight;
                      final needsScroll = totalItemsHeight > availableHeight;

                      if (needsScroll) {
                        // Si necesita scroll, usar SingleChildScrollView
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
                                      ? Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => onItemTapped(item.index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12, // Aumentado de 8 a 12
                                        horizontal: 8,  // Aumentado de 4 a 8
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected
                                                ? item.selectedIcon
                                                : item.icon,
                                            size: 26,  // Aumentado de 20 a 26
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : null,
                                          ),
                                          const SizedBox(height: 8), // Aumentado de 4 a 8
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 13, // Aumentado de 10 a 13
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
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
                        // Si no necesita scroll, usar NavigationRail normal
                        return NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: onItemTapped,
                          labelType: NavigationRailLabelType.all,
                          minWidth: 140, // Aumentado de 100 a 140
                          minExtendedWidth: 140, // Añadido para asegurar el ancho mínimo
                          groupAlignment: 0.0, // Centrar los ítems
                          leading: const SizedBox(height: 20), // Espacio adicional en la parte superior
                          trailing: const SizedBox(height: 20), // Espacio adicional en la parte inferior
                          destinations: NavigationItem.items.map((item) {
                            return NavigationRailDestination(
                              icon: Icon(item.icon, size: 26), // Aumentado de 20 a 26
                              label: Padding(
                                padding: const EdgeInsets.only(top: 6), // Añadido espacio arriba del texto
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13, // Aumentado de 10 a 13
                                    fontWeight: FontWeight.w500, // Texto un poco más grueso
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              selectedIcon: Icon(item.selectedIcon, size: 26), // Aumentado de 20 a 26
                            );
                          }).toList(),
                        );
                      }
                    },
                  ),
                ),
                // Botón de salida con más espacio
                Container(
                  padding: const EdgeInsets.all(12), // Aumentado de 4 a 12
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 12), // Aumentado de 8 a 12
                        color: Theme.of(context).dividerColor,
                      ),
                      const SizedBox(height: 12), // Añadido espacio
                      InkWell(
                        onTap: () {
                          // Cerrar sesión
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12, // Aumentado de 8 a 12
                            horizontal: 8,  // Aumentado de 4 a 8
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.logout, size: 24), // Aumentado de 18 a 24
                              SizedBox(height: 6), // Aumentado de 2 a 6
                              Text(
                                'Cerrar Sesión', // Texto más descriptivo
                                style: TextStyle(fontSize: 13), // Aumentado de 10 a 13
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
          // Contenido principal con ancho restringido
          Expanded(
            child: SafeConstraints(
              maxWidth: screenSize.width - 100,
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ),
        ],
      ),
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
