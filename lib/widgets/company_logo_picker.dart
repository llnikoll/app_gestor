import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/logo_service.dart';

class CompanyLogoPicker extends StatelessWidget {
  final double size;

  const CompanyLogoPicker({
    super.key,
    this.size = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LogoService>(
      builder: (context, logoService, child) {
        return GestureDetector(
          onTap: () => logoService.pickAndSaveLogo(),
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2.0,
                  ),
                  image: logoService.logoPath != null
                      ? DecorationImage(
                          image: FileImage(File(logoService.logoPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: logoService.logoPath == null
                    ? Center(
                        child: Icon(
                          Icons.business,
                          size: size * 0.5,
                          color: Colors.grey[600],
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}