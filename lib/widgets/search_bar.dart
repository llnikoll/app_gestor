import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String hintText;
  final bool autofocus;
  final bool showClearButton;
  final bool showSearchIcon;
  final bool showMicIcon;
  final bool showBarcodeScanner;
  final VoidCallback? onBarcodeScanned;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText = 'Buscar...',
    this.autofocus = false,
    this.showClearButton = true,
    this.showSearchIcon = true,
    this.showMicIcon = false,
    this.showBarcodeScanner = true,
    this.onBarcodeScanned,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  SearchBarState createState() => SearchBarState();
}

class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear código de barras'),
        centerTitle: true,
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture barcodes) {
          if (barcodes.barcodes.isNotEmpty) {
            final barcode = barcodes.barcodes.first;
            if (barcode.rawValue != null) {
              Navigator.of(context).pop(barcode.rawValue);
            }
          }
        },
      ),
    );
  }
}

class SearchBarState extends State<SearchBar> {
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  void _onClear() {
    widget.controller.clear();
    widget.onChanged('');
    if (widget.onClear != null) {
      widget.onClear!();
    }
  }

  Future<void> _scanBarcode() async {
    // Mostrar un diálogo con el escáner de códigos de barras
    if (widget.onBarcodeScanned != null) {
      widget.onBarcodeScanned!();
    } else {
      // Si no hay un manejador personalizado, mostramos el escáner por defecto
      if (!mounted) return;
      
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );
      
      if (barcode != null && barcode.isNotEmpty) {
        widget.controller.text = barcode;
        widget.onChanged(barcode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (_hasFocus)
            BoxShadow(
              color: theme.primaryColor.withAlpha(51), // 255 * 0.2 ≈ 51
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.hintColor,
          ),
          prefixIcon: widget.showSearchIcon
              ? Icon(
                  Icons.search,
                  color: _hasFocus
                      ? theme.primaryColor
                      : theme.hintColor,
                )
              : null,
          suffixIcon: _buildSuffixIcons(theme),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
        ),
        cursorColor: theme.primaryColor,
        autocorrect: false,
        enableSuggestions: false,
        autofocus: widget.autofocus,
      ),
    );
  }

  Widget? _buildSuffixIcons(ThemeData theme) {
    final List<Widget> icons = [];

    // Botón para limpiar el texto
    if (widget.showClearButton &&
        widget.controller.text.isNotEmpty &&
        _hasFocus) {
      icons.add(
        IconButton(
          icon: Icon(Icons.clear, color: theme.hintColor),
          onPressed: _onClear,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    // Botón para escanear código de barras
    if (widget.showBarcodeScanner) {
      icons.add(
        IconButton(
          icon: Icon(
            Icons.barcode_reader,
            color: _hasFocus ? theme.primaryColor : theme.hintColor,
          ),
          onPressed: _scanBarcode,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    // Botón de micrófono (opcional)
    if (widget.showMicIcon) {
      icons.add(
        IconButton(
          icon: Icon(
            Icons.mic,
            color: _hasFocus ? theme.primaryColor : theme.hintColor,
          ),
          onPressed: () {
            // Lógica para reconocimiento de voz
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    if (icons.isEmpty) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: icons,
    );
  }
}
