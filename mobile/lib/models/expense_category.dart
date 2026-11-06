import 'package:flutter/material.dart';

/// Categorías ofrecidas en el formulario. La API guarda la categoría como texto.
enum ExpenseCategory {
  food('Alimentación', Icons.restaurant),
  transport('Transporte', Icons.local_taxi),
  lodging('Hospedaje', Icons.hotel),
  stationery('Papelería', Icons.edit_note),
  other('Otros', Icons.receipt_long);

  const ExpenseCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Ícono para una categoría recibida de la API (puede venir de otro cliente).
  static IconData iconFor(String category) {
    for (final value in values) {
      if (value.label.toLowerCase() == category.trim().toLowerCase()) return value.icon;
    }
    return Icons.receipt_long;
  }
}
