/// Tunable thresholds for face recognition. These are starting values: they
/// must be checked with real faces and adjusted if people are mis-recognised
/// (raise [matchThreshold]) or not recognised (lower it).
class FaceConfig {
  const FaceConfig._();

  /// Minimum similarity (0..1, Human's `match.similarity`) to count as the
  /// same person.
  static const matchThreshold = 0.6;

  /// The best match must beat the next-best *other* person by this much,
  /// otherwise the result is ambiguous and ignored.
  static const matchMargin = 0.05;

  /// Consecutive polls that must agree on the same person.
  static const stableFrames = 3;

  /// Consecutive unmatched polls before saying the face is not registered.
  static const unknownFrames = 4;

  /// Best-effort anti-spoof scores (0..1, higher is stricter). Weak: a still
  /// face photo shown on a screen scored real 0.81 / live 0.97 in a manual
  /// check, so this does not stop someone holding up a photo of a colleague.
  static const minReal = 0.5;
  static const minLive = 0.5;

  /// Enrolment: samples to capture, min detector score, and polls to skip
  /// between samples so they are not near-identical frames.
  static const enrollSamples = 3;
  static const enrollMinScore = 0.8;
  static const enrollGapPolls = 2;

  static const pollInterval = Duration(milliseconds: 400);
}
