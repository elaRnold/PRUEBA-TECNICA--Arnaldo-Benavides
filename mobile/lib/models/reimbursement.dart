enum ReimbursementStatus {
  pending('Pending', 'Pendiente'),
  approved('Approved', 'Aprobada'),
  rejected('Rejected', 'Rechazada');

  const ReimbursementStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ReimbursementStatus fromApi(String value) {
    for (final status in values) {
      if (status.apiValue.toLowerCase() == value.toLowerCase()) return status;
    }
    throw FormatException('Estado desconocido: $value');
  }
}

class Reimbursement {
  const Reimbursement({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAtUtc,
    this.rejectionReason,
    this.decidedAtUtc,
  });

  final int id;
  final String employeeName;
  final double amount;
  final String category;
  final String description;
  final ReimbursementStatus status;
  final String? rejectionReason;
  final DateTime createdAtUtc;
  final DateTime? decidedAtUtc;

  /// Lanza [FormatException] si el JSON no tiene la forma esperada.
  factory Reimbursement.fromJson(Map<String, dynamic> json) {
    try {
      final decided = json['decidedAtUtc'] as String?;
      return Reimbursement(
        id: json['id'] as int,
        employeeName: json['employeeName'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        description: json['description'] as String,
        status: ReimbursementStatus.fromApi(json['status'] as String),
        rejectionReason: json['rejectionReason'] as String?,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
        decidedAtUtc: decided == null ? null : DateTime.parse(decided),
      );
    } on TypeError {
      throw const FormatException('La respuesta del servidor no tiene el formato esperado.');
    }
  }
}
