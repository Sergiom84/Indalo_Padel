class ApiError {
  final String message;
  final int? statusCode;

  const ApiError({required this.message, this.statusCode});

  @override
  String toString() => message;
}
