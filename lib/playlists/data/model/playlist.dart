import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:json_annotation/json_annotation.dart';

part 'playlist.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class Playlist extends Equatable {
  const Playlist(
    this.id,
    this.name,
    this.products,
    this.createdAt, {
    this.skipIntros = false,
    this.sleepMode = false,
  });

  @HiveField(0)
  final String id;
  @JsonKey(name: 'list')
  @HiveField(1)
  final String name;
  @HiveField(2)
  final List<Product> products;
  @HiveField(3)
  final DateTime? createdAt;

  /// Playlist-level Skip Intros setting. Persisted locally (Hive) only — never
  /// sent to or read from the server.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @HiveField(4, defaultValue: false)
  final bool skipIntros;

  /// Playlist-level Sleep Mode setting. Persisted locally (Hive) only — never
  /// sent to or read from the server.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @HiveField(5, defaultValue: false)
  final bool sleepMode;

  factory Playlist.mocked() => Playlist(
      'id', 'name', [Product.mocked('Example audio 1')], DateTime.now());

  /// Connect the generated [_$PlaylistFromJson] function to the `fromJson`
  /// factory.
  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  /// Connect the generated [_$PlaylistToJson] function to the `toJson` method.
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  Playlist copyWith({
    String? id,
    String? name,
    List<Product>? products,
    DateTime? createdAt,
    bool? skipIntros,
    bool? sleepMode,
  }) {
    return Playlist(
      id ?? this.id,
      name ?? this.name,
      products ?? this.products,
      createdAt ?? this.createdAt,
      skipIntros: skipIntros ?? this.skipIntros,
      sleepMode: sleepMode ?? this.sleepMode,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, products, createdAt, skipIntros, sleepMode];
}
