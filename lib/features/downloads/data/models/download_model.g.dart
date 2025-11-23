// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadModelAdapter extends TypeAdapter<DownloadModel> {
  @override
  final int typeId = 1;

  @override
  DownloadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadModel(
      id: fields[0] as String,
      url: fields[1] as String,
      filename: fields[2] as String,
      savedPath: fields[3] as String?,
      totalBytes: fields[4] as int,
      downloadedBytes: fields[5] as int,
      statusIndex: fields[6] as int,
      createdAt: fields[7] as DateTime,
      completedAt: fields[8] as DateTime?,
      errorMessage: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.filename)
      ..writeByte(3)
      ..write(obj.savedPath)
      ..writeByte(4)
      ..write(obj.totalBytes)
      ..writeByte(5)
      ..write(obj.downloadedBytes)
      ..writeByte(6)
      ..write(obj.statusIndex)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.errorMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
