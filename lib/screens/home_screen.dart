import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/navigation_item.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'auth/login_screen.dart';
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
        final screenSize = MediaQuery.of(context).size;
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

class _HomeScreenContent extends StatefulWidget {
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
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;
    
    setState(() {
      _isSigningOut = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      // Usar un postFrameCallback para asegurar que el contexto sea válido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
        // Solo intentar cerrar el drawer si el widget aún está en el árbol
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      key: widget.scaffoldKey,
      appBar: AppBar(
        title: Text(NavigationItem.fromIndex(widget.selectedIndex).title),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildDrawer(context),
      body: SafeConstraints(
        maxWidth: screenSize.width,
        child: IndexedStack(
          index: widget.selectedIndex.clamp(0, widget.screens.length - 1),
          children: widget.screens,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return SizedBox(
      width: isWideScreen ? screenWidth * 0.25 : screenWidth * 0.7,
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
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin@minegocio.com',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  color: widget.selectedIndex == item.index
                      ? Theme.of(context).primaryColor.withAlpha(26)
                      : Colors.transparent,
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    widget.selectedIndex == item.index
                        ? item.selectedIcon
                        : item.icon,
                    color: widget.selectedIndex == item.index
                        ? Theme.of(context).primaryColor
                        : null,
                    size: 22,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: isWideScreen ? 14 : 13,
                      fontWeight: widget.selectedIndex == item.index
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.onItemTapped(item.index);
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
                leading: _isSigningOut
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout, size: 22),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _isSigningOut ? null : _handleSignOut,
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

  bool _handlePop() {
    if (_selectedIndex != 0) {
      onItemTapped(0);
      return false;
    }
    return true;
  }

  Widget _buildMobileLayout() {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
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
    return PopScope(
      canPop: _selectedIndex == 0,
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
                    color: Theme.of(context).dividerColor,
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
                      backgroundColor: Theme.of(context).primaryColor,
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
                        final itemHeight = 72.0;
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
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withAlpha(26)
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
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
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
                        }

                        return Column(
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
                                      ).primaryColor.withAlpha(26)
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
                                              ? Theme.of(context).primaryColor
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
                                                ? Theme.of(context).primaryColor
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _HomeScreenContent(
                selectedIndex: _selectedIndex.clamp(0, _screens.length - 1),
                onItemTapped: onItemTapped,
                screens: _screens,
                scaffoldKey: _scaffoldKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }
}
