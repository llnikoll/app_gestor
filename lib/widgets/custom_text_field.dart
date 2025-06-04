import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart' as validator_pkg;

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSaved,
    this.onFieldSubmitted,
    this.onTap,
    this.validator,
    this.validators,
    this.showError = true,
    this.autoValidate = false,
    this.contentPadding,
    this.initialValue,
    this.isRequired = false,
    this.requiredErrorText,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.enableInteractiveSelection = true,
    this.textAlignVertical,
    this.expands = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String?>? onSaved;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final List<validator_pkg.FieldValidator>? validators;
  final bool showError;
  final bool autoValidate;
  final EdgeInsetsGeometry? contentPadding;
  final String? initialValue;
  final bool isRequired;
  final String? requiredErrorText;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final bool enableInteractiveSelection;
  final TextAlignVertical? textAlignVertical;
  final bool expands;

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  late final List<dynamic> _validators;
  late final TextEditingController _controller;
  bool _isFocused = false;
  bool _showPassword = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _focusNode = widget.focusNode ?? FocusNode();
    _validators = [
      if (widget.validators != null) ...widget.validators!,
      if (widget.validator != null) 
        (String? value) => widget.validator!(value),
      if (widget.isRequired)
        validator_pkg.RequiredValidator(errorText: widget.requiredErrorText ?? 'Este campo es obligatorio'),
    ] as List<dynamic>;
    
    // Inicializar el controlador con el valor inicial si se proporciona
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    // No se debe desechar el controlador si fue proporcionado desde fuera
    if (_controller != widget.controller) {
      _controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value) {
    // Si no hay validadores, retornar null (válido)
    if ((widget.validators == null || widget.validators!.isEmpty) && 
        widget.validator == null && 
        !widget.isRequired) {
      return null;
    }
    
    // Aplicar validadores uno por uno
    for (final validator in _validators) {
      try {
        final dynamic result = validator is validator_pkg.FieldValidator
            ? validator.call(value ?? '')
            : validator(value);
            
        if (result != null && result is String && result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        debugPrint('Error en validador: $e');
        continue;
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPasswordField = widget.obscureText;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(222), // 0.87 * 255 ≈ 222
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Campo de texto
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {
              _isFocused = hasFocus;
            });
          },
          child: TextFormField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            obscureText: isPasswordField ? !_showPassword : false,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            onChanged: widget.onChanged,
            onSaved: widget.onSaved,
            onFieldSubmitted: widget.onFieldSubmitted,
            onTap: widget.onTap,
            validator: _validate,
            autovalidateMode: widget.autoValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            textAlign: widget.textAlign,
            focusNode: widget.focusNode,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            textAlignVertical: widget.textAlignVertical,
            expands: widget.expands,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: widget.prefixIcon,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              suffixIcon: _buildSuffixIcon(theme, isPasswordField),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              contentPadding: widget.contentPadding ??
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
              filled: !widget.enabled,
              fillColor: !widget.enabled
                  ? theme.colorScheme.surface.withAlpha(128) // 255 * 0.5 ≈ 128
                  : null,
              errorStyle: widget.showError
                  ? theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    )
                  : const TextStyle(fontSize: 0, height: 0),
              errorMaxLines: 2,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon(ThemeData theme, bool isPasswordField) {
    // Si es un campo de contraseña, mostrar el botón para mostrar/ocultar
    if (isPasswordField) {
      return IconButton(
        icon: Icon(
          _showPassword ? Icons.visibility_off : Icons.visibility,
          color: theme.hintColor,
        ),
        onPressed: () {
          setState(() {
            _showPassword = !_showPassword;
          });
        },
      );
    }
    
    // Si hay un sufijo personalizado, mostrarlo
    if (widget.suffixIcon != null) {
      return widget.suffixIcon;
    }
    
    // Si el campo está enfocado y tiene texto, mostrar botón para limpiar
    if (_isFocused && _controller.text.isNotEmpty) {
      return IconButton(
        icon: Icon(Icons.clear, color: theme.hintColor),
        onPressed: () {
          _controller.clear();
          if (widget.onChanged != null) {
            widget.onChanged!('');
          }
        },
      );
    }
    
    return null;
  }
}
