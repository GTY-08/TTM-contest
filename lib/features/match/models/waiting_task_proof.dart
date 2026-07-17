class WaitingTaskProof {
  const WaitingTaskProof({
    required this.id,
    required this.requestId,
    required this.workerId,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String workerId;
  final String imageUrl;
  final DateTime createdAt;

  factory WaitingTaskProof.fromMap(Map<String, dynamic> map) {
    return WaitingTaskProof(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      workerId: map['worker_id'] as String,
      imageUrl: map['image_url'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
