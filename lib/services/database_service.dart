import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
import '../models/venta_model.dart';
import '../models/cliente_model.dart';
import '../models/entrada_inventario_model.dart';
import '../models/gasto_model.dart';

class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  // Database configuration
  static const String _databaseName = 'gestor_ventas.db';
  static const int _databaseVersion =
      15; // Forzar recreación de tabla ventas

  // Table names
  static const String tableClientes = 'clientes';
  static const String tableCategorias = 'categorias';
  static const String tableProductos = 'productos';
  static const String tableVentas = 'ventas';
  static const String tableVentaDetalles = 'venta_detalles';
  static const String tableEntradasInventario = 'entradas_inventario';
  static const String tableProveedores = 'proveedores';
  static const String tableGastos = 'gastos';

  // Private constructor
  DatabaseService._internal();

  // Factory constructor to return the same instance
  factory DatabaseService() => _instance;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  // Create tables
  Future<void> _onCreate(Database db, int version) async {
    // Create clientes table
    await db.execute('''
      CREATE TABLE $tableClientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        direccion TEXT,
        telefono TEXT,
        email TEXT,
        ruc TEXT,
        notas TEXT,
        fecha_registro TEXT NOT NULL
      )
    ''');

    // Create categorias table
    await db.execute('''
      CREATE TABLE $tableCategorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL
      )
    ''');

    // Create productos table
    await db.execute('''
      CREATE TABLE $tableProductos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_barras TEXT NOT NULL UNIQUE,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        categoria_id INTEGER NOT NULL,
        precio_compra REAL NOT NULL,
        precio_venta REAL NOT NULL,
        stock INTEGER NOT NULL,
        stock_minimo INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        imagen_url TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (categoria_id) REFERENCES $tableCategorias(id)
      )
    ''');

    // Create ventas table
    await db.execute('''
      CREATE TABLE $tableVentas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        cliente TEXT,
        total REAL NOT NULL,
        fecha TEXT NOT NULL,
        metodo_pago TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'Completada',
        notas TEXT,
        referencia_pago TEXT,
        FOREIGN KEY (cliente_id) REFERENCES $tableClientes(id)
      )
    ''');

    // Create venta_detalles table
    await db.execute('''
      CREATE TABLE $tableVentaDetalles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES $tableVentas(id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES $tableProductos(id)
      )
    ''');

    // Create entradas_inventario table
    await db.execute('''
      CREATE TABLE $tableEntradasInventario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        producto_nombre TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        total REAL NOT NULL,
        fecha TEXT NOT NULL,
        notas TEXT,
        proveedor_id INTEGER,
        proveedor_nombre TEXT,
        FOREIGN KEY (producto_id) REFERENCES $tableProductos(id)
      )
    ''');

    // Create gastos table
    await db.execute('''
      CREATE TABLE $tableGastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion TEXT NOT NULL,
        monto REAL NOT NULL,
        categoria TEXT NOT NULL,
        fecha TEXT NOT NULL,
        comprobante_url TEXT,
        notas TEXT,
        producto_id INTEGER,
        FOREIGN KEY (producto_id) REFERENCES $tableProductos(id)
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_productos_codigo ON $tableProductos(codigo_barras)',
    );
    await db.execute(
      'CREATE INDEX idx_productos_nombre ON $tableProductos(nombre)',
    );
    await db.execute('CREATE INDEX idx_ventas_fecha ON $tableVentas(fecha)');
    await db.execute(
      'CREATE INDEX idx_venta_detalles_venta_id ON $tableVentaDetalles(venta_id)',
    );
    await db.execute(
      'CREATE INDEX idx_gastos_producto_id ON $tableGastos(producto_id)',
    );

    // Insert default category
    await db.insert(tableCategorias, {
      'nombre': 'General',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate to version 2: Add stock_minimo to productos table
      await db.execute(
        'ALTER TABLE $tableProductos ADD COLUMN stock_minimo INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // Migrate to version 3: Add activo column to productos table
      await db.execute(
        'ALTER TABLE $tableProductos ADD COLUMN activo INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      // Migrate to version 4: Add entradas_inventario table
      await db.execute('''
        CREATE TABLE $tableEntradasInventario (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          producto_id INTEGER NOT NULL,
          cantidad INTEGER NOT NULL,
          precio_compra REAL NOT NULL,
          fecha TEXT NOT NULL,
          notas TEXT,
          FOREIGN KEY (producto_id) REFERENCES $tableProductos(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      // Migrate to version 5: Add proveedores table
      await db.execute('''
        CREATE TABLE $tableProveedores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          contacto TEXT,
          telefono TEXT,
          email TEXT,
          direccion TEXT,
          notas TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      // Migrate to version 6: Add gastos table
      await db.execute('''
        CREATE TABLE $tableGastos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descripcion TEXT NOT NULL,
          monto REAL NOT NULL,
          fecha TEXT NOT NULL,
          categoria TEXT,
          notas TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      // Migrate to version 7: Add producto_id to gastos table (nullable)
      await db.execute(
        'ALTER TABLE $tableGastos ADD COLUMN producto_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE $tableGastos ADD COLUMN es_gasto_operativo INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 8) {
      // Migrate to version 8: Make producto_id in gastos table NOT NULL with default -1
      // First, create a new table with the desired schema
      await db.execute('''
        CREATE TABLE ${tableGastos}_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descripcion TEXT NOT NULL,
          monto REAL NOT NULL,
          fecha TEXT NOT NULL,
          categoria TEXT,
          notas TEXT,
          producto_id INTEGER NOT NULL DEFAULT -1,
          es_gasto_operativo INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Copy data from old table to new table
      await db.execute('''
        INSERT INTO ${tableGastos}_new 
        (id, descripcion, monto, fecha, categoria, notas, producto_id, es_gasto_operativo)
        SELECT id, descripcion, monto, fecha, categoria, notas, 
               COALESCE(producto_id, -1) as producto_id, 
               COALESCE(es_gasto_operativo, 0) as es_gasto_operativo
        FROM $tableGastos
      ''');

      // Drop old table and rename new one
      await db.execute('DROP TABLE $tableGastos');
      await db.execute('ALTER TABLE ${tableGastos}_new RENAME TO $tableGastos');
    }
    if (oldVersion < 9) {
      // Migrate to version 9: Recreate ventas table with correct schema
      try {
        // 1. Crear nueva tabla con la estructura correcta
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${tableVentas}_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cliente_id INTEGER,
            cliente TEXT,
            total REAL NOT NULL,
            fecha TEXT NOT NULL,
            metodo_pago TEXT NOT NULL,
            estado TEXT NOT NULL DEFAULT 'Completada',
            notas TEXT,
            referencia_pago TEXT,
            FOREIGN KEY (cliente_id) REFERENCES $tableClientes(id)
          )
        ''');

        // 2. Copiar datos de la tabla antigua a la nueva si existe
        try {
          await db.execute('''
            INSERT INTO ${tableVentas}_new 
            (id, cliente_id, cliente, total, fecha, metodo_pago, estado, notas, referencia_pago)
            SELECT id, cliente_id, cliente, total, fecha, metodo_pago, estado, COALESCE(notas, ''), COALESCE(referencia_pago, '')
            FROM $tableVentas
          ''');
        } catch (e) {
          debugPrint('No se pudieron migrar los datos: $e');
          // Continuar de todos modos, la tabla se creará vacía
        }

        // 3. Eliminar tabla antigua si existe
        try {
          await db.execute('DROP TABLE IF EXISTS $tableVentas');
        } catch (e) {
          debugPrint('No se pudo eliminar la tabla antigua: $e');
        }

        // 4. Renombrar nueva tabla
        await db.execute('ALTER TABLE ${tableVentas}_new RENAME TO $tableVentas');
        debugPrint('Tabla ventas recreada exitosamente con la columna referencia_pago');
      } catch (e) {
        debugPrint('Error crítico al recrear tabla ventas: $e');
        rethrow;
      }
    }

    if (oldVersion < 10) {
      // Migrate to version 10: Add categorias table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCategorias (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          fecha_creacion TEXT NOT NULL
        )
      ''');

      // Insert default category if table was just created
      await db.insert(tableCategorias, {
        'nombre': 'General',
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
    }
  }

  // ========== VENTA METHODS ==========

  // Obtener detalles de una venta
  Future<List<Map<String, dynamic>>> getDetallesVenta(int ventaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT vd.*, p.nombre as nombre_producto 
      FROM $tableVentaDetalles vd
      JOIN $tableProductos p ON vd.producto_id = p.id
      WHERE vd.venta_id = ?
    ''',
      [ventaId],
    );

    return maps;
  }

  // Obtener todos los clientes con opción de búsqueda
  Future<List<Cliente>> getClientes({String? searchQuery}) async {
    final db = await database;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Búsqueda por nombre, email, teléfono o RUC
      final List<Map<String, dynamic>> maps = await db.query(
        tableClientes,
        where: 'nombre LIKE ? OR email LIKE ? OR telefono LIKE ? OR ruc LIKE ?',
        whereArgs: [
          '%$searchQuery%',
          '%$searchQuery%',
          '%$searchQuery%',
          '%$searchQuery%',
        ],
        orderBy: 'nombre ASC',
      );
      return List.generate(maps.length, (i) => Cliente.fromMap(maps[i]));
    } else {
      // Si no hay término de búsqueda, devolver todos los clientes
      final List<Map<String, dynamic>> maps = await db.query(
        tableClientes,
        orderBy: 'nombre ASC',
      );
      return List.generate(maps.length, (i) => Cliente.fromMap(maps[i]));
    }
  }

  // Insertar una nueva venta
  Future<int> insertVenta(Venta venta) async {
    final db = await database;
    int ventaId = 0; // Initialize with default value

    await db.transaction((txn) async {
      // Insert sale
      ventaId = await txn.insert(tableVentas, {
        'cliente_id': venta.clienteId,
        'cliente': venta.clienteNombre,
        'total': venta.total,
        'fecha': venta.fecha.toIso8601String(),
        'metodo_pago': venta.metodoPago,
        'referencia_pago': venta.referenciaPago,
        'estado': venta.estado,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert sale details
      for (var item in venta.items) {
        await txn.insert(tableVentaDetalles, {
          'venta_id': ventaId,
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad'],
          'precio_unitario': item['precio_unitario'],
          'subtotal': item['subtotal'],
        });

        // Update product stock
        await txn.rawUpdate(
          'UPDATE $tableProductos SET stock = stock - ? WHERE id = ?',
          [item['cantidad'], item['producto_id']],
        );
      }
    });

    return ventaId;
  }

  // Insertar detalle de venta
  Future<void> insertVentaDetalle({
    required int ventaId,
    required int productoId,
    required int cantidad,
    required double precioUnitario,
    required double subtotal,
  }) async {
    final db = await database;
    await db.insert(tableVentaDetalles, {
      'venta_id': ventaId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    });
  }

  // Actualizar stock de un producto
  Future<void> actualizarStockProducto(int productoId, int cantidad) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableProductos 
      SET stock = stock + ? 
      WHERE id = ?
    ''',
      [cantidad, productoId],
    );
  }

  // Registrar compra de producto existente
  Future<void> registrarCompraProducto({
    required int productoId,
    required String productoNombre,
    required int cantidad,
    required double precioUnitario,
    String? notas,
    int? proveedorId,
    String? proveedorNombre,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // Actualizar stock
      await txn.rawUpdate(
        'UPDATE $tableProductos SET stock = stock + ? WHERE id = ?',
        [cantidad, productoId],
      );

      // Registrar entrada en el inventario
      final total = cantidad * precioUnitario;
      final fechaActual = DateTime.now();
      final fechaStr = fechaActual.toIso8601String();

      await txn.insert(tableEntradasInventario, {
        'producto_id': productoId,
        'producto_nombre': productoNombre,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'total': total,
        'fecha': fechaStr,
        'notas': notas,
        'proveedor_id': proveedorId,
        'proveedor_nombre': proveedorNombre,
      });

      // Registrar el gasto asociado a la compra
      await txn.insert(tableGastos, {
        'descripcion': 'Compra de $productoNombre (x$cantidad)',
        'monto': total,
        'categoria': 'Insumos',
        'fecha': fechaStr,
        'notas': notas,
        'producto_id': productoId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // ========== CLIENT METHODS ==========

  Future<int> insertCliente(Cliente cliente) async {
    final db = await database;
    return await db.insert(tableClientes, cliente.toMap());
  }

  Future<Cliente?> getCliente(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableClientes,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Cliente.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Cliente>> getAllClientes({String? searchQuery}) async {
    final db = await database;

    List<Map<String, dynamic>> maps;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      maps = await db.query(
        tableClientes,
        where: 'nombre LIKE ? OR email LIKE ? OR telefono LIKE ?',
        whereArgs: ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%'],
      );
    } else {
      maps = await db.query(tableClientes);
    }

    return List.generate(maps.length, (i) => Cliente.fromMap(maps[i]));
  }

  Future<int> updateCliente(Cliente cliente) async {
    final db = await database;
    return await db.update(
      tableClientes,
      cliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  Future<int> deleteCliente(int id) async {
    final db = await database;
    return await db.delete(tableClientes, where: 'id = ?', whereArgs: [id]);
  }

  // Gasto methods are defined later in the file with more complete implementations

  // Product CRUD operations
  Future<int> insertProducto(Producto producto) async {
    final db = await database;
    final map = producto.toMap();

    // Obtener o crear la categoría
    final categoriaId = await _getCategoriaId(map['categoria']);

    // Mapear los nombres de las columnas al esquema de la base de datos
    final mappedMap = {
      'codigo_barras': map['codigoBarras'],
      'nombre': map['nombre'],
      'descripcion': map['descripcion'],
      'categoria_id': categoriaId,
      'precio_compra': map['precioCompra'],
      'precio_venta': map['precioVenta'],
      'stock': map['stock'],
      'fecha_creacion': map['fechaCreacion'] is String
          ? map['fechaCreacion']
          : (map['fechaCreacion'] as DateTime).toIso8601String(),
      'imagen_url': map['imagenUrl'],
      'activo': 1,
    };

    return await db.insert(tableProductos, mappedMap);
  }

  // Método auxiliar para obtener el ID de la categoría por nombre
  Future<int> _getCategoriaId(String nombreCategoria) async {
    final db = await database;
    final result = await db.query(
      tableCategorias,
      where: 'nombre = ?',
      whereArgs: [nombreCategoria],
      columns: ['id'],
    );

    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }

    // Si no existe la categoría, crearla
    final id = await db.insert(tableCategorias, {
      'nombre': nombreCategoria,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<Producto?> getProducto(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.*, c.nombre as categoria_nombre 
      FROM $tableProductos p
      LEFT JOIN $tableCategorias c ON p.categoria_id = c.id
      WHERE p.id = ?
    ''',
      [id],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Producto(
        id: map['id'],
        codigoBarras: map['codigo_barras'] ?? '',
        nombre: map['nombre'] ?? '',
        descripcion: map['descripcion'] ?? '',
        categoria: map['categoria_nombre'] ?? 'General',
        precioCompra: (map['precio_compra'] as num?)?.toDouble() ?? 0.0,
        precioVenta: (map['precio_venta'] as num?)?.toDouble() ?? 0.0,
        stock: map['stock'] ?? 0,
        fechaCreacion: map['fecha_creacion'] != null
            ? DateTime.parse(map['fecha_creacion'])
            : DateTime.now(),
        fechaActualizacion: map['fecha_actualizacion'] != null
            ? DateTime.parse(map['fecha_actualizacion'])
            : null,
        imagenUrl: map['imagen_url'],
        activo: map['activo'] == 1,
      );
    }
    return null;
  }

  Future<Producto?> getProductoPorCodigo(String codigoBarras) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.*, c.nombre as categoria_nombre 
      FROM $tableProductos p
      LEFT JOIN $tableCategorias c ON p.categoria_id = c.id
      WHERE p.codigo_barras = ?
    ''',
      [codigoBarras],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Producto(
        id: map['id'],
        codigoBarras: map['codigo_barras'] ?? '',
        nombre: map['nombre'] ?? '',
        descripcion: map['descripcion'] ?? '',
        categoria: map['categoria_nombre'] ?? 'General',
        precioCompra: (map['precio_compra'] as num?)?.toDouble() ?? 0.0,
        precioVenta: (map['precio_venta'] as num?)?.toDouble() ?? 0.0,
        stock: map['stock'] ?? 0,
        fechaCreacion: map['fecha_creacion'] != null
            ? DateTime.parse(map['fecha_creacion'])
            : DateTime.now(),
        fechaActualizacion: map['fecha_actualizacion'] != null
            ? DateTime.parse(map['fecha_actualizacion'])
            : null,
        imagenUrl: map['imagen_url'],
        activo: map['activo'] == 1,
      );
    }
    return null;
  }

  Future<List<Producto>> getProductos({String? categoria}) async {
    final db = await database;

    List<Map<String, dynamic>> maps;
    if (categoria != null && categoria.isNotEmpty) {
      maps = await db.rawQuery(
        '''
        SELECT p.*, c.nombre as categoria_nombre 
        FROM $tableProductos p
        INNER JOIN $tableCategorias c ON p.categoria_id = c.id
        WHERE c.nombre = ? AND p.activo = 1
      ''',
        [categoria],
      );
    } else {
      maps = await db.rawQuery('''
        SELECT p.*, c.nombre as categoria_nombre 
        FROM $tableProductos p
        INNER JOIN $tableCategorias c ON p.categoria_id = c.id
        WHERE p.activo = 1
      ''');
    }

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return Producto(
        id: map['id'],
        codigoBarras: map['codigo_barras'] ?? '',
        nombre: map['nombre'] ?? '',
        descripcion: map['descripcion'] ?? '',
        categoria: map['categoria_nombre'] ?? 'General',
        precioCompra: (map['precio_compra'] as num?)?.toDouble() ?? 0.0,
        precioVenta: (map['precio_venta'] as num?)?.toDouble() ?? 0.0,
        stock: map['stock'] ?? 0,
        fechaCreacion: map['fecha_creacion'] != null
            ? DateTime.parse(map['fecha_creacion'])
            : DateTime.now(),
        fechaActualizacion: map['fecha_actualizacion'] != null
            ? DateTime.parse(map['fecha_actualizacion'])
            : null,
        imagenUrl: map['imagen_url'],
        activo: map['activo'] == 1,
      );
    });
  }

  Future<int> updateProducto(Producto producto) async {
    final db = await database;
    final map = producto.toMap();

    // Obtener o crear la categoría
    final categoriaId = await _getCategoriaId(map['categoria']);

    // Mapear los nombres de las columnas al esquema de la base de datos
    final mappedMap = {
      'codigo_barras': map['codigoBarras'],
      'nombre': map['nombre'],
      'descripcion': map['descripcion'],
      'categoria_id': categoriaId,
      'precio_compra': map['precioCompra'],
      'precio_venta': map['precioVenta'],
      'stock': map['stock'],
      'imagen_url': map['imagenUrl'],
      'activo': map['activo'] == true ? 1 : 0,
    };

    // Si hay una fecha de creación, asegurarse de que esté en el formato correcto
    if (map['fechaCreacion'] != null) {
      mappedMap['fecha_creacion'] = map['fechaCreacion'] is String
          ? map['fechaCreacion']
          : (map['fechaCreacion'] as DateTime).toIso8601String();
    }

    return await db.update(
      tableProductos,
      mappedMap,
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return await db.update(
      tableProductos,
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Category CRUD operations
  Future<int> insertCategoria(Categoria categoria) async {
    final db = await database;
    final map = categoria.toMap();
    // Asegurarse de que el nombre de la columna coincida con la base de datos
    map['fecha_creacion'] = map.remove('fechaCreacion');

    return await db.insert(
      tableCategorias,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Categoria>> getCategorias() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCategorias);

    return maps.map((map) {
      // Mapear los nombres de las columnas de la base de datos al modelo
      return Categoria(
        id: map['id'],
        nombre: map['nombre'],
        fechaCreacion: DateTime.parse(map['fecha_creacion']),
      );
    }).toList();
  }

  Future<Categoria?> getCategoriaById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCategorias,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Categoria(
        id: map['id'],
        nombre: map['nombre'],
        fechaCreacion: DateTime.parse(map['fecha_creacion']),
      );
    }
    return null;
  }

  Future<int> updateCategoria(Categoria categoria) async {
    final db = await database;
    final map = categoria.toMap();
    // Asegurarse de que el nombre de la columna coincida con la base de datos
    map['fecha_creacion'] = map.remove('fechaCreacion');

    return await db.update(
      tableCategorias,
      map,
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  Future<int> deleteCategoria(int id) async {
    final db = await database;
    // Check if there are products using this category
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $tableProductos WHERE categoria_id = ?',
        [id],
      ),
    );

    if (count != null && count > 0) {
      throw Exception(
        'No se puede eliminar la categoría porque tiene productos asociados',
      );
    }

    return await db.delete(tableCategorias, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Venta>> getVentas() async {
    final db = await database;

    // Verificar si la columna referencia_pago existe
    final hasReferenciaPago = await _columnExists(
      tableVentas,
      'referencia_pago',
    );

    // Definir las columnas a seleccionar
    final columns = [
      'id',
      'fecha',
      'cliente_id',
      'cliente',
      'total',
      'metodo_pago',
      if (hasReferenciaPago) 'referencia_pago',
    ];

    // Realizar la consulta
    final List<Map<String, dynamic>> maps = await db.query(
      tableVentas,
      columns: columns,
      orderBy: 'fecha DESC',
    );

    final ventas = <Venta>[];
    for (var ventaMap in maps) {
      try {
        final detalles = await getVentaDetalles(ventaMap['id']);
        final venta = Venta.fromMap(ventaMap);
        venta.items.addAll(detalles);
        ventas.add(venta);
      } catch (e) {
        debugPrint('Error al procesar venta ${ventaMap['id']}: $e');
      }
    }
    return ventas;
  }

  Future<List<Map<String, dynamic>>> getVentaDetalles(int ventaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT vd.*, p.nombre as nombre_producto 
      FROM $tableVentaDetalles vd
      LEFT JOIN $tableProductos p ON vd.producto_id = p.id
      WHERE vd.venta_id = ?
    ''',
      [ventaId],
    );

    return maps;
  }

  // Search products by name or barcode
  Future<List<Producto>> buscarProductos(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableProductos,
      where: 'nombre LIKE ? OR codigo_barras LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );

    return List.generate(maps.length, (i) => Producto.fromMap(maps[i]));
  }

  // ========== ENTRADAS DE INVENTARIO ==========

  // Insertar una nueva entrada de inventario
  Future<int> insertEntradaInventario(EntradaInventario entrada) async {
    final db = await database;

    // Iniciar transacción
    return await db.transaction((txn) async {
      // 1. Insertar la entrada de inventario
      final id = await txn.insert(
        tableEntradasInventario,
        entrada.toMap()..remove('id'),
      );

      // 2. Actualizar el stock del producto
      await txn.rawUpdate(
        ''' 
        UPDATE $tableProductos 
        SET stock = stock + ? 
        WHERE id = ?
      ''',
        [entrada.cantidad, entrada.productoId],
      );

      return id;
    });
  }

  // Obtener todas las entradas de inventario con información del producto
  Future<List<EntradaInventario>> getEntradasInventario({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? productoId,
  }) async {
    final db = await database;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (fechaInicio != null) {
      where += ' AND e.fecha >= ?';
      whereArgs.add(fechaInicio.toIso8601String());
    }

    if (fechaFin != null) {
      where += ' AND e.fecha <= ?';
      whereArgs.add(fechaFin.toIso8601String());
    }

    if (productoId != null) {
      where += ' AND e.producto_id = ?';
      whereArgs.add(productoId);
    }

    // Realizar una consulta que una la tabla de entradas con la de productos
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, p.imagen_url as producto_imagen_url, p.descripcion as producto_descripcion,
             p.precio_venta as producto_precio_venta, p.stock as producto_stock
      FROM $tableEntradasInventario e
      LEFT JOIN $tableProductos p ON e.producto_id = p.id
      WHERE $where
      ORDER BY e.fecha DESC
    ''', whereArgs);

    // Mapear los resultados a objetos EntradaInventario
    return List.generate(maps.length, (i) {
      final map = maps[i];
      // Crear el objeto EntradaInventario con los datos adicionales del producto
      return EntradaInventario(
        id: map['id'],
        productoId: map['producto_id'],
        productoNombre: map['producto_nombre'],
        cantidad: map['cantidad'],
        precioUnitario: (map['precio_unitario'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha']),
        notas: map['notas'],
        proveedorId: map['proveedor_id'],
        proveedorNombre: map['proveedor_nombre'],
        productoImagenUrl: map['producto_imagen_url'],
        productoDescripcion: map['producto_descripcion'],
        productoPrecioVenta: (map['producto_precio_venta'] as num?)?.toDouble(),
        productoStock: map['producto_stock'] ?? 0,
      );
    });
  }

  // Obtener el total gastado en inventario
  Future<double> getTotalGastadoInventario({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final db = await database;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (fechaInicio != null) {
      where += ' AND fecha >= ?';
      whereArgs.add(fechaInicio.toIso8601String());
    }

    if (fechaFin != null) {
      where += ' AND fecha <= ?';
      whereArgs.add(fechaFin.toIso8601String());
    }

    final result = await db.rawQuery(''' 
      SELECT SUM(total) as total 
      FROM $tableEntradasInventario 
      WHERE $where
    ''', whereArgs);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ========== MÉTODOS DE GASTOS ==========

  // Insertar un nuevo gasto
  Future<int> insertGasto(Gasto gasto) async {
    final db = await database;
    final map = gasto.toMap()..remove('id');

    if (kDebugMode) {
      debugPrint('Insertando gasto: $map');
    }

    final id = await db.insert(
      tableGastos,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (kDebugMode) {
      debugPrint('Gasto insertado con ID: $id');
    }

    return id;
  }

  // Actualizar un gasto existente
  Future<int> updateGasto(Gasto gasto) async {
    if (gasto.id == null) throw Exception('ID del gasto no puede ser nulo');

    final db = await database;
    return await db.update(
      tableGastos,
      gasto.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [gasto.id],
    );
  }

  // Eliminar un gasto
  Future<int> deleteGasto(int id) async {
    final db = await database;
    return await db.delete(tableGastos, where: 'id = ?', whereArgs: [id]);
  }

  // Obtener todos los gastos
  Future<List<Gasto>> getGastos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableGastos,
      orderBy: 'fecha DESC',
    );
    return List.generate(maps.length, (i) => Gasto.fromMap(maps[i]));
  }

  // Obtener gastos por rango de fechas
  Future<List<Gasto>> getGastosPorRangoFechas(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    final db = await database;

    // Asegurarse de que las fechas estén en el rango correcto del día
    final fechaInicioAjustada = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );
    final fechaFinAjustada = DateTime(
      fechaFin.year,
      fechaFin.month,
      fechaFin.day,
      23,
      59,
      59,
      999,
    );

    // Convertir a ISO 8601 para la consulta
    final fechaInicioStr = fechaInicioAjustada.toIso8601String();
    final fechaFinStr = fechaFinAjustada.toIso8601String();

    if (kDebugMode) {
      debugPrint('Buscando gastos entre $fechaInicioStr y $fechaFinStr');
      debugPrint('Fecha inicio (DateTime): $fechaInicioAjustada');
      debugPrint('Fecha fin (DateTime): $fechaFinAjustada');
    }

    try {
      // Primero, obtener todos los gastos para depuración
      if (kDebugMode) {
        final allGastos = await db.query(tableGastos);
        debugPrint('Total de gastos en la base de datos: ${allGastos.length}');
        for (var i = 0; i < allGastos.length && i < 5; i++) {
          debugPrint('Gasto ${i + 1}: ${allGastos[i]}');
        }
      }

      // Usar una consulta raw con comparación directa de fechas ISO 8601
      final query =
          '''
        SELECT * FROM $tableGastos 
        WHERE fecha >= ? AND fecha <= ?
        ORDER BY fecha DESC
      ''';

      if (kDebugMode) {
        debugPrint('Ejecutando consulta SQL:');
        debugPrint('  $query');
        debugPrint('  Parámetros: [$fechaInicioStr, $fechaFinStr]');
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, [
        fechaInicioStr,
        fechaFinStr,
      ]);

      if (kDebugMode) {
        debugPrint('Consulta SQL ejecutada. Resultados: ${maps.length}');
        for (var i = 0; i < maps.length && i < 5; i++) {
          debugPrint('  Gasto ${i + 1}: ${maps[i]}');
        }
      }

      final gastos = List.generate(maps.length, (i) {
        try {
          return Gasto.fromMap(maps[i]);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error al convertir mapa a Gasto: $e');
            debugPrint('Mapa con error: ${maps[i]}');
          }
          rethrow;
        }
      });

      return gastos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en getGastosPorRangoFechas: $e');
      }
      rethrow;
    }
  }

  // Obtener total de gastos por rango de fechas
  Future<double> getTotalGastosPorRangoFechas(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(monto) as total 
      FROM $tableGastos 
      WHERE fecha BETWEEN ? AND ?
    ''',
      [fechaInicio.toIso8601String(), fechaFin.toIso8601String()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Obtener gastos agrupados por categoría
  Future<List<Map<String, dynamic>>> getGastosPorCategoria(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        categoria, 
        SUM(monto) as total,
        COUNT(*) as cantidad
      FROM $tableGastos
      WHERE fecha BETWEEN ? AND ?
      GROUP BY categoria
      ORDER BY total DESC
    ''',
      [fechaInicio.toIso8601String(), fechaFin.toIso8601String()],
    );
  }

  // Verificar si una columna existe en una tabla
  Future<bool> _columnExists(String tableName, String columnName) async {
    try {
      final db = await database;
      final result = await db.rawQuery("PRAGMA table_info($tableName)");
      return result.any((column) => column['name'] == columnName);
    } catch (e) {
      debugPrint('Error al verificar columna $columnName: $e');
      return false;
    }
  }

  // Obtener ventas por rango de fechas
  Future<List<Venta>> getVentasPorRangoFechas(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    final db = await database;

    // Verificar si la columna referencia_pago existe
    final hasReferenciaPago = await _columnExists(
      tableVentas,
      'referencia_pago',
    );

    // Definir las columnas a seleccionar
    final columns = [
      'id',
      'fecha',
      'cliente_id',
      'cliente',
      'total',
      'metodo_pago',
      if (hasReferenciaPago) 'referencia_pago',
    ];

    // Realizar la consulta
    final List<Map<String, dynamic>> maps = await db.query(
      tableVentas,
      columns: columns,
      where: 'fecha BETWEEN ? AND ?',
      whereArgs: [fechaInicio.toIso8601String(), fechaFin.toIso8601String()],
      orderBy: 'fecha DESC',
    );

    final ventas = <Venta>[];
    for (var ventaMap in maps) {
      try {
        final detalles = await getVentaDetalles(ventaMap['id']);
        final venta = Venta.fromMap(ventaMap);
        venta.items.addAll(detalles);
        ventas.add(venta);
      } catch (e) {
        debugPrint('Error al procesar venta ${ventaMap['id']}: $e');
      }
    }
    return ventas;
  }

  // Cerrar la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
