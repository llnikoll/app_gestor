import 'package:flutter/material.dart';

/// Un botón personalizado que puede mostrarse como elevado o con borde.
///
/// Para usar dentro de un [Row] o [Column], considera usar [isFullWidth] = false
/// o envolverlo en un [Expanded] o [Flexible] según sea necesario.
///
/// Ejemplo de uso:
/// ```dart
/// // Botón de ancho completo
/// PrimaryButton(
///   text: 'Guardar',
///   onPressed: () {},
///   isFullWidth: true,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final bool isOutlined;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.color,
    this.textColor,
    this.width,
    this.height = 48,
    this.borderRadius = 8,
    this.padding,
    this.elevation = 2,
    this.isOutlined = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.primaryColor;
    final buttonTextColor = textColor ?? theme.colorScheme.onPrimary;
    final effectiveOnPressed = isDisabled || isLoading ? null : onPressed;

    // Widget de contenido del botón
    Widget buildContent() {
      if (isLoading) {
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isOutlined ? buttonColor : buttonTextColor,
            ),
            strokeWidth: 2,
          ),
        );
      }

      if (icon == null) {
        return Text(
          text,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    }

    // Función para ajustar la opacidad usando withAlpha
    Color withOpacityValue(Color color, double opacity) {
      return color.withAlpha((opacity * 255).round());
    }

    // Estilo base
    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? withOpacityValue(buttonColor, 0.5)
            : (isOutlined ? null : buttonColor),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? withOpacityValue(buttonTextColor, 0.5)
            : (isOutlined ? buttonColor : buttonTextColor),
      ),
      side: WidgetStateProperty.all<BorderSide?>(
        isOutlined ? BorderSide(color: buttonColor, width: 2) : null,
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      minimumSize: WidgetStateProperty.all<Size>(
        Size(width ?? 0, height ?? 48),
      ),
      elevation: WidgetStateProperty.all<double>(
        isOutlined ? 0 : elevation,
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.pressed)
            ? withOpacityValue(buttonColor, 0.2)
            : null,
      ),
    );

    // Widget base del botón
    final button = isOutlined
        ? OutlinedButton(
            onPressed: effectiveOnPressed,
            style: buttonStyle,
            child: buildContent(),
          )
        : ElevatedButton(
            onPressed: effectiveOnPressed,
            style: buttonStyle,
            child: buildContent(),
          );

    // Si se solicita ancho completo, lo envolvemos en un Container con ancho infinito
    // Nota: El widget padre debe poder manejar el ancho infinito (como un Column)
    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }


    // Si tiene un ancho específico, lo devolvemos con ese ancho
    if (width != null) {
      return SizedBox(
        width: width,
        child: button,
      );
    }

    // Si no tiene restricciones de ancho, devolvemos el botón directamente
    return button;
  }
}

// Botón secundario que hereda de PrimaryButton
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final bool isFullWidth;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
    this.height = 48,
    this.borderRadius = 8,
    this.padding,
    this.elevation = 0,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isDisabled: isDisabled,
      icon: icon,
      width: width,
      height: height,
      borderRadius: borderRadius,
      padding: padding,
      elevation: elevation,
      isFullWidth: isFullWidth,
      isOutlined: true,
      color: theme.colorScheme.surface,
      textColor: theme.primaryColor,
    );
  }
}

// Botón de texto personalizado
class CustomTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isDisabled;
  final IconData? icon;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? iconSize;
  final double spacing;
  final bool underline;

  const CustomTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isDisabled = false,
    this.icon,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.iconSize = 20,
    this.spacing = 4,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.primaryColor;

    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return textColor.withAlpha(97); // 255 * 0.38 ≈ 97
          }
          return textColor;
        }),
        overlayColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          return textColor.withAlpha(31); // 255 * 0.12 ≈ 31
        }),
        padding: WidgetStateProperty.all<EdgeInsets>(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            SizedBox(width: spacing),
          ],
          Text(
            text,
            style: TextStyle(
              color: isDisabled
                  ? textColor.withAlpha(97) // 38% de opacidad (255 * 0.38 ≈ 97)
                  : textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
