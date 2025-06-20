class Currency {
  final String code;
  final String name;
  final String symbol;
  final String locale;
  final int decimalDigits;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.locale,
    this.decimalDigits = 2,
  });

  // Monedas soportadas
  static const List<Currency> currencies = [
    Currency(
      code: 'PYG',
      name: 'Guaraní Paraguayo',
      symbol: '₲',
      locale: 'es_PY',
      decimalDigits: 0,
    ),
    Currency(
      code: 'USD',
      name: 'Dólar Estadounidense',
      symbol: '\$',
      locale: 'en_US',
    ),
    Currency(
      code: 'BRL',
      name: 'Real Brasileño',
      symbol: 'R\$',
      locale: 'pt_BR',
    ),
    Currency(
      code: 'ARS',
      name: 'Peso Argentino',
      symbol: '\$',
      locale: 'es_AR',
    ),
    Currency(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      locale: 'es_ES',
    ),
  ];

  // Obtener moneda por código
  static Currency getByCode(String code) {
    return currencies.firstWhere(
      (currency) => currency.code == code,
      orElse: () => currencies.first, // Retorna PYG por defecto
    );
  }
}
