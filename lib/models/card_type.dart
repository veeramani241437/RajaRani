enum CardType {
  king('KING', 'King', 'ராஜா', 1000),
  queen('QUEEN', 'Queen', 'ராணி', 900),
  prince('PRINCE', 'Prince', 'இளவரசர்', 800),
  commander('COMMANDER', 'Commander', 'தளபதி', 700),
  minister('MINISTER', 'Minister', 'மந்திரி', 600),
  soldier('SOLDIER', 'Soldier', 'வீரன்', 500),
  merchant('MERCHANT', 'Merchant', 'வியாபாரி', 300),
  citizen('CITIZEN', 'Citizen', 'குடிமகன்', 200),
  police('POLICE', 'Police', 'பொலிஸ்காரன்', 100),
  thief('THIEF', 'Thief', 'திருடன்', 0);

  final String dbValue;
  final String englishName;
  final String tamilName;
  final int points;

  const CardType(this.dbValue, this.englishName, this.tamilName, this.points);

  static CardType fromDbValue(String? value) {
    if (value == null) return CardType.thief;
    return CardType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => CardType.thief,
    );
  }
}
