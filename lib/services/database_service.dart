import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
import '../models/venta_model.dart';
import '../models/cliente_model.dart';

class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  // Database configuration
  static const String _databaseName = 'gestor_ventas.db';
  static const int _databaseVersion = 4;

  // Table names
  static const String tableClientes = 'clientes';
  static const String tableCategorias = 'categorias';
  static const String tableProductos = 'productos';
  static const String tableVentas = 'ventas';
  static const String tableVentaDetalles = 'venta_detalles';

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
        nombre TEXT NOT NULL UNIQUE,
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
        total REAL NOT NULL,
        fecha TEXT NOT NULL,
        metodo_pago TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'Completada',
        notas TEXT,
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
    
    // Create indexes
    await db.execute('CREATE INDEX idx_productos_codigo ON $tableProductos(codigo_barras)');
    await db.execute('CREATE INDEX idx_productos_nombre ON $tableProductos(nombre)');
    await db.execute('CREATE INDEX idx_ventas_fecha ON $tableVentas(fecha)');
    await db.execute('CREATE INDEX idx_venta_detalles_venta_id ON $tableVentaDetalles(venta_id)');
    
    // Insert default category
    await db.insert(tableCategorias, {
      'nombre': 'General',
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  // Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Drop all tables if they exist
      await db.execute('DROP TABLE IF EXISTS $tableVentaDetalles');
      await db.execute('DROP TABLE IF EXISTS $tableVentas');
      await db.execute('DROP TABLE IF EXISTS $tableProductos');
      await db.execute('DROP TABLE IF EXISTS $tableCategorias');
      await db.execute('DROP TABLE IF EXISTS $tableClientes');
      
      // Recreate all tables with the new schema
      await _onCreate(db, newVersion);
    }
  }

  // Client CRUD operations
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
    return await db.delete(
      tableClientes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

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
      'fecha_creacion': map['fechaCreacion'] is String ? map['fechaCreacion'] : (map['fechaCreacion'] as DateTime).toIso8601String(),
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
    final id = await db.insert(
      tableCategorias,
      {
        'nombre': nombreCategoria,
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
    );
    return id;
  }

  Future<Producto?> getProducto(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.nombre as categoria_nombre 
      FROM $tableProductos p
      LEFT JOIN $tableCategorias c ON p.categoria_id = c.id
      WHERE p.id = ?
    ''', [id]);
    
    if (maps.isNotEmpty) {
      final map = maps.first;
      return Producto(
        id: map['id'],
        codigoBarras: map['codigo_barras'] ?? '',
        nombre: map['nombre'] ?? '',
        descripcion: map['descripcion'] ?? '',
        categoria: map['categoria_nombre'] ?? 'General',
        precioCompra: (map['precio_compra'] as num).toDouble(),
        precioVenta: (map['precio_venta'] as num).toDouble(),
        stock: map['stock'] ?? 0,
        fechaCreacion: DateTime.parse(map['fecha_creacion']),
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
    final List<Map<String, dynamic>> maps = await db.query(
      tableProductos,
      where: 'codigo_barras = ?',
      whereArgs: [codigoBarras],
    );
    
    if (maps.isNotEmpty) {
      return Producto.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Producto>> getProductos({String? categoria}) async {
    final db = await database;
    
    List<Map<String, dynamic>> maps;
    if (categoria != null && categoria.isNotEmpty) {
      maps = await db.rawQuery('''
        SELECT p.*, c.nombre as categoria 
        FROM $tableProductos p
        INNER JOIN $tableCategorias c ON p.categoria_id = c.id
        WHERE p.categoria_id = ? AND p.activo = 1
      ''', [categoria]);
    } else {
      maps = await db.rawQuery('''
        SELECT p.*, c.nombre as categoria 
        FROM $tableProductos p
        INNER JOIN $tableCategorias c ON p.categoria_id = c.id
        WHERE p.activo = 1
      ''');
    }
    
    return List.generate(maps.length, (i) => Producto.fromMap(maps[i]));
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
      'fecha_actualizacion': DateTime.now().toIso8601String(),
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
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $tableProductos WHERE categoria_id = ?',
      [id],
    ));
    
    if (count != null && count > 0) {
      throw Exception('No se puede eliminar la categoría porque tiene productos asociados');
    }
    
    return await db.delete(
      tableCategorias,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sale operations
  Future<int> insertVenta(Venta venta) async {
    final db = await database;
    int ventaId = 0; // Initialize with default value
    
    await db.transaction((txn) async {
      // Insert sale
      ventaId = await txn.insert(tableVentas, venta.toMap());
      
      // Insert sale details
      for (var item in venta.items) {
        await txn.insert(
          tableVentaDetalles,
          {
            'venta_id': ventaId,
            'producto_id': item['producto_id'],
            'cantidad': item['cantidad'],
            'precio_unitario': item['precio_unitario'],
            'subtotal': item['subtotal'],
          },
        );
        
        // Update product stock
        await txn.rawUpdate(
          'UPDATE $tableProductos SET stock = stock - ? WHERE id = ?',
          [item['cantidad'], item['producto_id']],
        );
      }
    });
    
    return ventaId;
  }

  Future<List<Venta>> getVentas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableVentas,
      orderBy: 'fecha DESC',
    );
    
    final ventas = <Venta>[];
    for (var ventaMap in maps) {
      final detalles = await getVentaDetalles(ventaMap['id']);
      final venta = Venta.fromMap(ventaMap);
      venta.items.addAll(detalles);
      ventas.add(venta);
    }
    return ventas;
  }

  Future<List<Map<String, dynamic>>> getVentaDetalles(int ventaId) async {
    final db = await database;
    return await db.query(
      tableVentaDetalles,
      where: 'venta_id = ?',
      whereArgs: [ventaId],
    );
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

  // Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
