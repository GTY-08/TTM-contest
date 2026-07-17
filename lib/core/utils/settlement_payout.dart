/// 심부름 대금에서 서비스 수수료를 제외한 작업자의 데모 수익.
int workerNetAfterFee(int grossWon, {required bool isPremiumWorker}) {
  final feeRate = isPremiumWorker ? 0.05 : 0.10;
  return (grossWon * (1 - feeRate)).round();
}
