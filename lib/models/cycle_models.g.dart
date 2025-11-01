// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CycleRecordAdapter extends TypeAdapter<CycleRecord> {
  @override
  final int typeId = 2;

  @override
  CycleRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CycleRecord(
      date: fields[0] as DateTime,
      bbt: fields[1] as double?,
      testResult: fields[2] as TestResult,
      imagePath: fields[3] as String?,
      isTiming: fields[4] as bool,
      isPeriod: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CycleRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.bbt)
      ..writeByte(2)
      ..write(obj.testResult)
      ..writeByte(3)
      ..write(obj.imagePath)
      ..writeByte(4)
      ..write(obj.isTiming)
      ..writeByte(5)
      ..write(obj.isPeriod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CycleDataAdapter extends TypeAdapter<CycleData> {
  @override
  final int typeId = 0;

  @override
  CycleData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CycleData(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      averageCycleLength: fields[2] as int,
      isRegular: fields[3] as bool,
      records: (fields[4] as HiveList?)?.castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, CycleData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.averageCycleLength)
      ..writeByte(3)
      ..write(obj.isRegular)
      ..writeByte(4)
      ..write(obj.records);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CycleDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TestResultAdapter extends TypeAdapter<TestResult> {
  @override
  final int typeId = 1;

  @override
  TestResult read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TestResult.none;
      case 1:
        return TestResult.negative;
      case 2:
        return TestResult.positive;
      case 3:
        return TestResult.strongPositive;
      default:
        return TestResult.none;
    }
  }

  @override
  void write(BinaryWriter writer, TestResult obj) {
    switch (obj) {
      case TestResult.none:
        writer.writeByte(0);
        break;
      case TestResult.negative:
        writer.writeByte(1);
        break;
      case TestResult.positive:
        writer.writeByte(2);
        break;
      case TestResult.strongPositive:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
