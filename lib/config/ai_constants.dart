class AiConstants {
  const AiConstants._();

  // Model IDs are used for chunk/version identity, job dedupe and migration.
  static const String chatModelId = 'meta-llama-3.2-1b-instruct-q4km';
  static const String embeddingModelId = 'meta-llama-3.2-1b-embed-q4km';

  // Expected embedding dimensions for HNSW index.
  static const int embeddingDimensions = 768;

  // Mobile-safe cache hint (ObjectBox default is 2GB; this keeps pressure lower).
  static const int vectorCacheHintSizeKB = 262144; // 256 MB

  // RAG chunking and retrieval defaults.
  static const int chunkTargetTokens = 220;
  static const int chunkMaxTokens = 280;
  static const int chunkOverlapTokens = 40;
  static const int retrievalTopK = 8;
  static const int retrievalMaxContextTokens = 1400;

  // Model runtime defaults tuned for mid-range Android.
  static const int chatContextTokens = 2048;
  static const int chatMaxOutputTokens = 220;
  static const Duration modelIdleDisposeAfter = Duration(minutes: 3);
}
