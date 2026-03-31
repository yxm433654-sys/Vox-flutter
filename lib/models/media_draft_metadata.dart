class MediaDraftMetadata {
  const MediaDraftMetadata({
    this.width,
    this.height,
    this.durationSeconds,
  });

  final int? width;
  final int? height;
  final double? durationSeconds;

  double aspectRatio(double fallback) {
    if (width != null && height != null && width! > 0 && height! > 0) {
      return width! / height!;
    }
    return fallback;
  }
}
