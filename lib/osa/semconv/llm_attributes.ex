defmodule OpenTelemetry.SemConv.Incubating.LlmAttributes do
  @moduledoc """
  Llm semantic convention attributes.

  Namespace: `llm`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  The unique identifier of the LLM adapter being applied.

  Attribute: `llm.adapter.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `adapter-lora-v1`, `prefix-tuning-qa`, `prompt-adapter-code`
  """
  @spec llm_adapter_id() :: :"llm.adapter.id"
  def llm_adapter_id, do: :"llm.adapter.id"

  @doc """
  The strategy for merging adapter weights with the base model (e.g., additive, weighted).

  Attribute: `llm.adapter.merge_strategy`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `additive`, `weighted`, `concatenate`
  """
  @spec llm_adapter_merge_strategy() :: :"llm.adapter.merge_strategy"
  def llm_adapter_merge_strategy, do: :"llm.adapter.merge_strategy"

  @doc """
  The type of parameter-efficient adapter being applied to the base model.

  Attribute: `llm.adapter.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `lora`, `prefix`, `prompt_tuning`
  """
  @spec llm_adapter_type() :: :"llm.adapter.type"
  def llm_adapter_type, do: :"llm.adapter.type"

  @doc """
  Enumerated values for `llm.adapter.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `lora` | `"lora"` | lora |
  | `prefix` | `"prefix"` | prefix |
  | `prompt_tuning` | `"prompt_tuning"` | prompt_tuning |
  | `adapter` | `"adapter"` | adapter |
  | `ia3` | `"ia3"` | ia3 |
  """
  @spec llm_adapter_type_values() :: %{
    lora: :lora,
    prefix: :prefix,
    prompt_tuning: :prompt_tuning,
    adapter: :adapter,
    ia3: :ia3
  }
  def llm_adapter_type_values do
    %{
      lora: :lora,
      prefix: :prefix,
      prompt_tuning: :prompt_tuning,
      adapter: :adapter,
      ia3: :ia3
    }
  end

  defmodule LlmAdapterTypeValues do
    @moduledoc """
    Typed constants for the `llm.adapter.type` attribute.
    """

    @doc "lora"
    @spec lora() :: :lora
    def lora, do: :lora

    @doc "prefix"
    @spec prefix() :: :prefix
    def prefix, do: :prefix

    @doc "prompt_tuning"
    @spec prompt_tuning() :: :prompt_tuning
    def prompt_tuning, do: :prompt_tuning

    @doc "adapter"
    @spec adapter() :: :adapter
    def adapter, do: :adapter

    @doc "ia3"
    @spec ia3() :: :ia3
    def ia3, do: :ia3

  end

  @doc """
  Average latency per request in the batch in milliseconds.

  Attribute: `llm.batch.avg_latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `2000`
  """
  @spec llm_batch_avg_latency_ms() :: :"llm.batch.avg_latency_ms"
  def llm_batch_avg_latency_ms, do: :"llm.batch.avg_latency_ms"

  @doc """
  Fraction of batch requests that completed successfully, range [0.0, 1.0].

  Attribute: `llm.batch.completion_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.99`, `1.0`
  """
  @spec llm_batch_completion_rate() :: :"llm.batch.completion_rate"
  def llm_batch_completion_rate, do: :"llm.batch.completion_rate"

  @doc """
  Unique identifier for the LLM batch inference job.

  Attribute: `llm.batch.job_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `batch-001`, `llm-batch-2026-001`
  """
  @spec llm_batch_job_id() :: :"llm.batch.job_id"
  def llm_batch_job_id, do: :"llm.batch.job_id"

  @doc """
  Priority level of the batch inference job.

  Attribute: `llm.batch.priority`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `normal`, `low`
  """
  @spec llm_batch_priority() :: :"llm.batch.priority"
  def llm_batch_priority, do: :"llm.batch.priority"

  @doc """
  Enumerated values for `llm.batch.priority`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `high` | `"high"` | high |
  | `normal` | `"normal"` | normal |
  | `low` | `"low"` | low |
  """
  @spec llm_batch_priority_values() :: %{
    high: :high,
    normal: :normal,
    low: :low
  }
  def llm_batch_priority_values do
    %{
      high: :high,
      normal: :normal,
      low: :low
    }
  end

  defmodule LlmBatchPriorityValues do
    @moduledoc """
    Typed constants for the `llm.batch.priority` attribute.
    """

    @doc "high"
    @spec high() :: :high
    def high, do: :high

    @doc "normal"
    @spec normal() :: :normal
    def normal, do: :normal

    @doc "low"
    @spec low() :: :low
    def low, do: :low

  end

  @doc """
  Number of requests in the batch inference job.

  Attribute: `llm.batch.request_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `100`, `1000`
  """
  @spec llm_batch_request_count() :: :"llm.batch.request_count"
  def llm_batch_request_count, do: :"llm.batch.request_count"

  @doc """
  Reason the cached LLM response was evicted.

  Attribute: `llm.cache.eviction_reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ttl_expired`, `invalidated`
  """
  @spec llm_cache_eviction_reason() :: :"llm.cache.eviction_reason"
  def llm_cache_eviction_reason, do: :"llm.cache.eviction_reason"

  @doc """
  Enumerated values for `llm.cache.eviction_reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `ttl_expired` | `"ttl_expired"` | ttl_expired |
  | `capacity` | `"capacity"` | capacity |
  | `invalidated` | `"invalidated"` | invalidated |
  """
  @spec llm_cache_eviction_reason_values() :: %{
    ttl_expired: :ttl_expired,
    capacity: :capacity,
    invalidated: :invalidated
  }
  def llm_cache_eviction_reason_values do
    %{
      ttl_expired: :ttl_expired,
      capacity: :capacity,
      invalidated: :invalidated
    }
  end

  defmodule LlmCacheEvictionReasonValues do
    @moduledoc """
    Typed constants for the `llm.cache.eviction_reason` attribute.
    """

    @doc "ttl_expired"
    @spec ttl_expired() :: :ttl_expired
    def ttl_expired, do: :ttl_expired

    @doc "capacity"
    @spec capacity() :: :capacity
    def capacity, do: :capacity

    @doc "invalidated"
    @spec invalidated() :: :invalidated
    def invalidated, do: :invalidated

  end

  @doc """
  Whether the LLM response was served from a semantic cache.

  Attribute: `llm.cache.hit`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec llm_cache_hit() :: :"llm.cache.hit"
  def llm_cache_hit, do: :"llm.cache.hit"

  @doc """
  Hash of the cache key used to identify the cached LLM response.

  Attribute: `llm.cache.key_hash`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `a3f5c9d2`, `b8e12f47`
  """
  @spec llm_cache_key_hash() :: :"llm.cache.key_hash"
  def llm_cache_key_hash, do: :"llm.cache.key_hash"

  @doc """
  Time-to-live for the cached LLM response in milliseconds.

  Attribute: `llm.cache.ttl_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `60000`, `300000`, `3600000`
  """
  @spec llm_cache_ttl_ms() :: :"llm.cache.ttl_ms"
  def llm_cache_ttl_ms, do: :"llm.cache.ttl_ms"

  @doc """
  Whether chain-of-thought prompting was used for this request.

  Attribute: `llm.chain_of_thought.enabled`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec llm_chain_of_thought_enabled() :: :"llm.chain_of_thought.enabled"
  def llm_chain_of_thought_enabled, do: :"llm.chain_of_thought.enabled"

  @doc """
  Number of chain-of-thought reasoning steps in this LLM response.

  Attribute: `llm.chain_of_thought.steps`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec llm_chain_of_thought_steps() :: :"llm.chain_of_thought.steps"
  def llm_chain_of_thought_steps, do: :"llm.chain_of_thought.steps"

  @doc """
  Compression ratio for context (original_tokens / compressed_tokens).

  Attribute: `llm.context.compression.ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.5`, `2.0`, `3.5`
  """
  @spec llm_context_compression_ratio() :: :"llm.context.compression.ratio"
  def llm_context_compression_ratio, do: :"llm.context.compression.ratio"

  @doc """
  Strategy used for context compression.

  Attribute: `llm.context.compression.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `summarize`, `truncate`, `sliding_window`
  """
  @spec llm_context_compression_strategy() :: :"llm.context.compression.strategy"
  def llm_context_compression_strategy, do: :"llm.context.compression.strategy"

  @doc """
  Enumerated values for `llm.context.compression.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `summarize` | `"summarize"` | summarize |
  | `truncate` | `"truncate"` | truncate |
  | `sliding_window` | `"sliding_window"` | sliding_window |
  | `selective` | `"selective"` | selective |
  """
  @spec llm_context_compression_strategy_values() :: %{
    summarize: :summarize,
    truncate: :truncate,
    sliding_window: :sliding_window,
    selective: :selective
  }
  def llm_context_compression_strategy_values do
    %{
      summarize: :summarize,
      truncate: :truncate,
      sliding_window: :sliding_window,
      selective: :selective
    }
  end

  defmodule LlmContextCompressionStrategyValues do
    @moduledoc """
    Typed constants for the `llm.context.compression.strategy` attribute.
    """

    @doc "summarize"
    @spec summarize() :: :summarize
    def summarize, do: :summarize

    @doc "truncate"
    @spec truncate() :: :truncate
    def truncate, do: :truncate

    @doc "sliding_window"
    @spec sliding_window() :: :sliding_window
    def sliding_window, do: :sliding_window

    @doc "selective"
    @spec selective() :: :selective
    def selective, do: :selective

  end

  @doc """
  Number of tokens saved through compression.

  Attribute: `llm.context.compression.tokens_saved`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `512`, `2048`
  """
  @spec llm_context_compression_tokens_saved() :: :"llm.context.compression.tokens_saved"
  def llm_context_compression_tokens_saved, do: :"llm.context.compression.tokens_saved"

  @doc """
  Maximum token limit for the LLM context window.

  Attribute: `llm.context.max_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4096`, `32768`, `200000`
  """
  @spec llm_context_max_tokens() :: :"llm.context.max_tokens"
  def llm_context_max_tokens, do: :"llm.context.max_tokens"

  @doc """
  Number of messages in the conversation context sent to the LLM.

  Attribute: `llm.context.messages_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `10`, `50`
  """
  @spec llm_context_messages_count() :: :"llm.context.messages_count"
  def llm_context_messages_count, do: :"llm.context.messages_count"

  @doc """
  Number of times context overflow was handled in the session.

  Attribute: `llm.context.overflow_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec llm_context_overflow_count() :: :"llm.context.overflow_count"
  def llm_context_overflow_count, do: :"llm.context.overflow_count"

  @doc """
  Strategy used when context exceeds max_tokens.

  Attribute: `llm.context.overflow_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `truncate`, `sliding_window`, `summarize`
  """
  @spec llm_context_overflow_strategy() :: :"llm.context.overflow_strategy"
  def llm_context_overflow_strategy, do: :"llm.context.overflow_strategy"

  @doc """
  Enumerated values for `llm.context.overflow_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `truncate` | `"truncate"` | truncate |
  | `summarize` | `"summarize"` | summarize |
  | `compress` | `"compress"` | compress |
  | `reject` | `"reject"` | reject |
  | `sliding_window` | `"sliding_window"` | sliding_window |
  """
  @spec llm_context_overflow_strategy_values() :: %{
    truncate: :truncate,
    summarize: :summarize,
    compress: :compress,
    reject: :reject,
    sliding_window: :sliding_window
  }
  def llm_context_overflow_strategy_values do
    %{
      truncate: :truncate,
      summarize: :summarize,
      compress: :compress,
      reject: :reject,
      sliding_window: :sliding_window
    }
  end

  defmodule LlmContextOverflowStrategyValues do
    @moduledoc """
    Typed constants for the `llm.context.overflow_strategy` attribute.
    """

    @doc "truncate"
    @spec truncate() :: :truncate
    def truncate, do: :truncate

    @doc "summarize"
    @spec summarize() :: :summarize
    def summarize, do: :summarize

    @doc "compress"
    @spec compress() :: :compress
    def compress, do: :compress

    @doc "reject"
    @spec reject() :: :reject
    def reject, do: :reject

    @doc "sliding_window"
    @spec sliding_window() :: :sliding_window
    def sliding_window, do: :sliding_window

  end

  @doc """
  Context window utilization ratio [0.0, 1.0].

  Attribute: `llm.context.utilization`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.45`, `0.87`, `1.0`
  """
  @spec llm_context_utilization() :: :"llm.context.utilization"
  def llm_context_utilization, do: :"llm.context.utilization"

  @doc """
  Cost of input tokens for this LLM request in USD.

  Attribute: `llm.cost.input`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.001`, `0.02`
  """
  @spec llm_cost_input() :: :"llm.cost.input"
  def llm_cost_input, do: :"llm.cost.input"

  @doc """
  Cost of output tokens for this LLM request in USD.

  Attribute: `llm.cost.output`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.001`, `0.025`
  """
  @spec llm_cost_output() :: :"llm.cost.output"
  def llm_cost_output, do: :"llm.cost.output"

  @doc """
  Total cost of the LLM request in USD (input + output combined).

  Attribute: `llm.cost.total`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.002`, `0.045`
  """
  @spec llm_cost_total() :: :"llm.cost.total"
  def llm_cost_total, do: :"llm.cost.total"

  @doc """
  Compression ratio of student vs teacher model size [0.0, 1.0].

  Attribute: `llm.distillation.compression_ratio`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.1`, `0.25`, `0.5`
  """
  @spec llm_distillation_compression_ratio() :: :"llm.distillation.compression_ratio"
  def llm_distillation_compression_ratio, do: :"llm.distillation.compression_ratio"

  @doc """
  KL divergence loss between teacher and student distributions.

  Attribute: `llm.distillation.kl_divergence`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `0.12`, `0.31`
  """
  @spec llm_distillation_kl_divergence() :: :"llm.distillation.kl_divergence"
  def llm_distillation_kl_divergence, do: :"llm.distillation.kl_divergence"

  @doc """
  Identifier of the student model being trained.

  Attribute: `llm.distillation.student_model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `llama-3-8b`, `phi-3-mini`, `gemma-2b`
  """
  @spec llm_distillation_student_model() :: :"llm.distillation.student_model"
  def llm_distillation_student_model, do: :"llm.distillation.student_model"

  @doc """
  Identifier of the teacher model providing soft targets.

  Attribute: `llm.distillation.teacher_model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `gpt-4`, `claude-3-opus`, `llama-3-70b`
  """
  @spec llm_distillation_teacher_model() :: :"llm.distillation.teacher_model"
  def llm_distillation_teacher_model, do: :"llm.distillation.teacher_model"

  @doc """
  Dimensionality of the generated embedding vectors.

  Attribute: `llm.embedding.dimensions`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `384`, `768`, `1536`
  """
  @spec llm_embedding_dimensions() :: :"llm.embedding.dimensions"
  def llm_embedding_dimensions, do: :"llm.embedding.dimensions"

  @doc """
  The embedding model used to generate vector representations.

  Attribute: `llm.embedding.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `text-embedding-ada-002`, `nomic-embed-text`, `all-MiniLM-L6-v2`
  """
  @spec llm_embedding_model() :: :"llm.embedding.model"
  def llm_embedding_model, do: :"llm.embedding.model"

  @doc """
  Cosine similarity threshold above which embeddings are considered semantically similar.

  Attribute: `llm.embedding.similarity_threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.7`, `0.8`, `0.9`
  """
  @spec llm_embedding_similarity_threshold() :: :"llm.embedding.similarity_threshold"
  def llm_embedding_similarity_threshold, do: :"llm.embedding.similarity_threshold"

  @doc """
  Whether the evaluation score meets or exceeds the quality threshold.

  Attribute: `llm.evaluation.passes_threshold`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec llm_evaluation_passes_threshold() :: :"llm.evaluation.passes_threshold"
  def llm_evaluation_passes_threshold, do: :"llm.evaluation.passes_threshold"

  @doc """
  Name of the evaluation rubric used to score the response.

  Attribute: `llm.evaluation.rubric`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `helpfulness`, `accuracy`, `safety`, `coherence`
  """
  @spec llm_evaluation_rubric() :: :"llm.evaluation.rubric"
  def llm_evaluation_rubric, do: :"llm.evaluation.rubric"

  @doc """
  Quality evaluation score for the LLM response, range [0.0, 1.0].

  Attribute: `llm.evaluation.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.85`, `0.92`, `1.0`
  """
  @spec llm_evaluation_score() :: :"llm.evaluation.score"
  def llm_evaluation_score, do: :"llm.evaluation.score"

  @doc """
  User feedback signal for the LLM response.

  Attribute: `llm.feedback.thumbs`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `up`, `down`
  """
  @spec llm_feedback_thumbs() :: :"llm.feedback.thumbs"
  def llm_feedback_thumbs, do: :"llm.feedback.thumbs"

  @doc """
  Enumerated values for `llm.feedback.thumbs`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `up` | `"up"` | up |
  | `down` | `"down"` | down |
  | `neutral` | `"neutral"` | neutral |
  """
  @spec llm_feedback_thumbs_values() :: %{
    up: :up,
    down: :down,
    neutral: :neutral
  }
  def llm_feedback_thumbs_values do
    %{
      up: :up,
      down: :down,
      neutral: :neutral
    }
  end

  defmodule LlmFeedbackThumbsValues do
    @moduledoc """
    Typed constants for the `llm.feedback.thumbs` attribute.
    """

    @doc "up"
    @spec up() :: :up
    def up, do: :up

    @doc "down"
    @spec down() :: :down
    def down, do: :down

    @doc "neutral"
    @spec neutral() :: :neutral
    def neutral, do: :neutral

  end

  @doc """
  Number of few-shot examples included in the prompt.

  Attribute: `llm.few_shot.example_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `8`
  """
  @spec llm_few_shot_example_count() :: :"llm.few_shot.example_count"
  def llm_few_shot_example_count, do: :"llm.few_shot.example_count"

  @doc """
  Time in milliseconds to retrieve and rank few-shot examples.

  Attribute: `llm.few_shot.retrieval_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `25`, `120`
  """
  @spec llm_few_shot_retrieval_ms() :: :"llm.few_shot.retrieval_ms"
  def llm_few_shot_retrieval_ms, do: :"llm.few_shot.retrieval_ms"

  @doc """
  Strategy used to select few-shot examples.

  Attribute: `llm.few_shot.selection_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `similarity`, `diverse`
  """
  @spec llm_few_shot_selection_strategy() :: :"llm.few_shot.selection_strategy"
  def llm_few_shot_selection_strategy, do: :"llm.few_shot.selection_strategy"

  @doc """
  Enumerated values for `llm.few_shot.selection_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `random` | `"random"` | random |
  | `similarity` | `"similarity"` | similarity |
  | `diverse` | `"diverse"` | diverse |
  | `stratified` | `"stratified"` | stratified |
  """
  @spec llm_few_shot_selection_strategy_values() :: %{
    random: :random,
    similarity: :similarity,
    diverse: :diverse,
    stratified: :stratified
  }
  def llm_few_shot_selection_strategy_values do
    %{
      random: :random,
      similarity: :similarity,
      diverse: :diverse,
      stratified: :stratified
    }
  end

  defmodule LlmFewShotSelectionStrategyValues do
    @moduledoc """
    Typed constants for the `llm.few_shot.selection_strategy` attribute.
    """

    @doc "random"
    @spec random() :: :random
    def random, do: :random

    @doc "similarity"
    @spec similarity() :: :similarity
    def similarity, do: :similarity

    @doc "diverse"
    @spec diverse() :: :diverse
    def diverse, do: :diverse

    @doc "stratified"
    @spec stratified() :: :stratified
    def stratified, do: :stratified

  end

  @doc """
  The base model being fine-tuned.

  Attribute: `llm.finetune.base_model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-3-haiku`, `llama-3-8b`, `mistral-7b`
  """
  @spec llm_finetune_base_model() :: :"llm.finetune.base_model"
  def llm_finetune_base_model, do: :"llm.finetune.base_model"

  @doc """
  Number of training examples in the fine-tuning dataset.

  Attribute: `llm.finetune.dataset_size`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `5000`, `50000`
  """
  @spec llm_finetune_dataset_size() :: :"llm.finetune.dataset_size"
  def llm_finetune_dataset_size, do: :"llm.finetune.dataset_size"

  @doc """
  Unique identifier for the fine-tuning job.

  Attribute: `llm.finetune.job_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `ft-abc123`, `finetune-job-2026-001`
  """
  @spec llm_finetune_job_id() :: :"llm.finetune.job_id"
  def llm_finetune_job_id, do: :"llm.finetune.job_id"

  @doc """
  Final training loss value at the end of fine-tuning.

  Attribute: `llm.finetune.loss_final`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.05`, `0.12`, `0.35`
  """
  @spec llm_finetune_loss_final() :: :"llm.finetune.loss_final"
  def llm_finetune_loss_final, do: :"llm.finetune.loss_final"

  @doc """
  Total number of training steps in the fine-tuning job.

  Attribute: `llm.finetune.training_steps`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `100`, `500`, `2000`
  """
  @spec llm_finetune_training_steps() :: :"llm.finetune.training_steps"
  def llm_finetune_training_steps, do: :"llm.finetune.training_steps"

  @doc """
  Time in milliseconds from LLM function call generation to handler response.

  Attribute: `llm.function_call.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `150`, `2000`
  """
  @spec llm_function_call_latency_ms() :: :"llm.function_call.latency_ms"
  def llm_function_call_latency_ms, do: :"llm.function_call.latency_ms"

  @doc """
  Name of the function being invoked through the LLM function calling interface.

  Attribute: `llm.function_call.name`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `get_weather`, `search_database`, `send_email`
  """
  @spec llm_function_call_name() :: :"llm.function_call.name"
  def llm_function_call_name, do: :"llm.function_call.name"

  @doc """
  Strategy used to route function calls from the LLM response to handlers.

  Attribute: `llm.function_call.routing_strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `direct`, `fallback`, `parallel`
  """
  @spec llm_function_call_routing_strategy() :: :"llm.function_call.routing_strategy"
  def llm_function_call_routing_strategy, do: :"llm.function_call.routing_strategy"

  @doc """
  Enumerated values for `llm.function_call.routing_strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `direct` | `"direct"` | direct |
  | `fallback` | `"fallback"` | fallback |
  | `parallel` | `"parallel"` | parallel |
  | `sequential` | `"sequential"` | sequential |
  """
  @spec llm_function_call_routing_strategy_values() :: %{
    direct: :direct,
    fallback: :fallback,
    parallel: :parallel,
    sequential: :sequential
  }
  def llm_function_call_routing_strategy_values do
    %{
      direct: :direct,
      fallback: :fallback,
      parallel: :parallel,
      sequential: :sequential
    }
  end

  defmodule LlmFunctionCallRoutingStrategyValues do
    @moduledoc """
    Typed constants for the `llm.function_call.routing_strategy` attribute.
    """

    @doc "direct"
    @spec direct() :: :direct
    def direct, do: :direct

    @doc "fallback"
    @spec fallback() :: :fallback
    def fallback, do: :fallback

    @doc "parallel"
    @spec parallel() :: :parallel
    def parallel, do: :parallel

    @doc "sequential"
    @spec sequential() :: :sequential
    def sequential, do: :sequential

  end

  @doc """
  Whether any guardrail was triggered for this LLM request or response.

  Attribute: `llm.guardrail.triggered`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  Examples: `true`, `false`
  """
  @spec llm_guardrail_triggered() :: :"llm.guardrail.triggered"
  def llm_guardrail_triggered, do: :"llm.guardrail.triggered"

  @doc """
  The type of guardrail that was evaluated or triggered.

  Attribute: `llm.guardrail.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `content_filter`, `pii_detection`
  """
  @spec llm_guardrail_type() :: :"llm.guardrail.type"
  def llm_guardrail_type, do: :"llm.guardrail.type"

  @doc """
  Enumerated values for `llm.guardrail.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `content_filter` | `"content_filter"` | content_filter |
  | `pii_detection` | `"pii_detection"` | pii_detection |
  | `prompt_injection` | `"prompt_injection"` | prompt_injection |
  | `hallucination_check` | `"hallucination_check"` | hallucination_check |
  | `rate_limit` | `"rate_limit"` | rate_limit |
  """
  @spec llm_guardrail_type_values() :: %{
    content_filter: :content_filter,
    pii_detection: :pii_detection,
    prompt_injection: :prompt_injection,
    hallucination_check: :hallucination_check,
    rate_limit: :rate_limit
  }
  def llm_guardrail_type_values do
    %{
      content_filter: :content_filter,
      pii_detection: :pii_detection,
      prompt_injection: :prompt_injection,
      hallucination_check: :hallucination_check,
      rate_limit: :rate_limit
    }
  end

  defmodule LlmGuardrailTypeValues do
    @moduledoc """
    Typed constants for the `llm.guardrail.type` attribute.
    """

    @doc "content_filter"
    @spec content_filter() :: :content_filter
    def content_filter, do: :content_filter

    @doc "pii_detection"
    @spec pii_detection() :: :pii_detection
    def pii_detection, do: :pii_detection

    @doc "prompt_injection"
    @spec prompt_injection() :: :prompt_injection
    def prompt_injection, do: :prompt_injection

    @doc "hallucination_check"
    @spec hallucination_check() :: :hallucination_check
    def hallucination_check, do: :hallucination_check

    @doc "rate_limit"
    @spec rate_limit() :: :rate_limit
    def rate_limit, do: :rate_limit

  end

  @doc """
  Total end-to-end latency of the LLM inference call in milliseconds.

  Attribute: `llm.latency_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `500`, `2000`, `10000`
  """
  @spec llm_latency_ms() :: :"llm.latency_ms"
  def llm_latency_ms, do: :"llm.latency_ms"

  @doc """
  Scaling factor for LoRA weight updates (alpha/rank determines effective learning rate).

  Attribute: `llm.lora.alpha`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `16.0`, `32.0`, `64.0`
  """
  @spec llm_lora_alpha() :: :"llm.lora.alpha"
  def llm_lora_alpha, do: :"llm.lora.alpha"

  @doc """
  Identifier of the base model being adapted with LoRA.

  Attribute: `llm.lora.base_model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `llama-3-8b`, `mistral-7b-v0.3`
  """
  @spec llm_lora_base_model() :: :"llm.lora.base_model"
  def llm_lora_base_model, do: :"llm.lora.base_model"

  @doc """
  Rank of the LoRA decomposition matrices (controls adaptation capacity).

  Attribute: `llm.lora.rank`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `4`, `8`, `16`, `64`
  """
  @spec llm_lora_rank() :: :"llm.lora.rank"
  def llm_lora_rank, do: :"llm.lora.rank"

  @doc """
  Comma-separated list of model modules targeted by LoRA adaptation.

  Attribute: `llm.lora.target_modules`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `q_proj,v_proj`, `all-linear`
  """
  @spec llm_lora_target_modules() :: :"llm.lora.target_modules"
  def llm_lora_target_modules, do: :"llm.lora.target_modules"

  @doc """
  Number of trainable parameters added by LoRA (much smaller than full fine-tune).

  Attribute: `llm.lora.trainable_params`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1048576`, `4194304`
  """
  @spec llm_lora_trainable_params() :: :"llm.lora.trainable_params"
  def llm_lora_trainable_params, do: :"llm.lora.trainable_params"

  @doc """
  The model identifier used for the LLM inference call.

  Attribute: `llm.model`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `gpt-4o`, `claude-opus-4-6`
  """
  @spec llm_model() :: :"llm.model"
  def llm_model, do: :"llm.model"

  @doc """
  Version identifier of the LLM model used.

  Attribute: `llm.model.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `claude-sonnet-4-6`, `gpt-4o`, `gemini-1.5-pro`
  """
  @spec llm_model_version() :: :"llm.model.version"
  def llm_model_version, do: :"llm.model.version"

  @doc """
  The model family/provider for this LLM inference (e.g., gpt, claude, gemini).

  Attribute: `llm.model_family`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `gpt`, `claude`
  """
  @spec llm_model_family() :: :"llm.model_family"
  def llm_model_family, do: :"llm.model_family"

  @doc """
  Enumerated values for `llm.model_family`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `gpt` | `"gpt"` | gpt |
  | `claude` | `"claude"` | claude |
  | `gemini` | `"gemini"` | gemini |
  | `llama` | `"llama"` | llama |
  | `mistral` | `"mistral"` | mistral |
  """
  @spec llm_model_family_values() :: %{
    gpt: :gpt,
    claude: :claude,
    gemini: :gemini,
    llama: :llama,
    mistral: :mistral
  }
  def llm_model_family_values do
    %{
      gpt: :gpt,
      claude: :claude,
      gemini: :gemini,
      llama: :llama,
      mistral: :mistral
    }
  end

  defmodule LlmModelFamilyValues do
    @moduledoc """
    Typed constants for the `llm.model_family` attribute.
    """

    @doc "gpt"
    @spec gpt() :: :gpt
    def gpt, do: :gpt

    @doc "claude"
    @spec claude() :: :claude
    def claude, do: :claude

    @doc "gemini"
    @spec gemini() :: :gemini
    def gemini, do: :gemini

    @doc "llama"
    @spec llama() :: :llama
    def llama, do: :llama

    @doc "mistral"
    @spec mistral() :: :mistral
    def mistral, do: :mistral

  end

  @doc """
  Total size in bytes of all non-text multi-modal inputs (images, audio, etc.).

  Attribute: `llm.multimodal.input_size_bytes`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `512000`, `2097152`
  """
  @spec llm_multimodal_input_size_bytes() :: :"llm.multimodal.input_size_bytes"
  def llm_multimodal_input_size_bytes, do: :"llm.multimodal.input_size_bytes"

  @doc """
  Primary input modality type for a multi-modal LLM request.

  Attribute: `llm.multimodal.input_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `image`, `document`
  """
  @spec llm_multimodal_input_type() :: :"llm.multimodal.input_type"
  def llm_multimodal_input_type, do: :"llm.multimodal.input_type"

  @doc """
  Enumerated values for `llm.multimodal.input_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `text` | `"text"` | text |
  | `image` | `"image"` | image |
  | `audio` | `"audio"` | audio |
  | `video` | `"video"` | video |
  | `document` | `"document"` | document |
  """
  @spec llm_multimodal_input_type_values() :: %{
    text: :text,
    image: :image,
    audio: :audio,
    video: :video,
    document: :document
  }
  def llm_multimodal_input_type_values do
    %{
      text: :text,
      image: :image,
      audio: :audio,
      video: :video,
      document: :document
    }
  end

  defmodule LlmMultimodalInputTypeValues do
    @moduledoc """
    Typed constants for the `llm.multimodal.input_type` attribute.
    """

    @doc "text"
    @spec text() :: :text
    def text, do: :text

    @doc "image"
    @spec image() :: :image
    def image, do: :image

    @doc "audio"
    @spec audio() :: :audio
    def audio, do: :audio

    @doc "video"
    @spec video() :: :video
    def video, do: :video

    @doc "document"
    @spec document() :: :document
    def document, do: :document

  end

  @doc """
  Number of distinct modalities present in the multi-modal LLM input.

  Attribute: `llm.multimodal.modality_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2`, `3`
  """
  @spec llm_multimodal_modality_count() :: :"llm.multimodal.modality_count"
  def llm_multimodal_modality_count, do: :"llm.multimodal.modality_count"

  @doc """
  Duration in milliseconds spent processing multi-modal inputs before inference.

  Attribute: `llm.multimodal.processing_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `120`, `800`
  """
  @spec llm_multimodal_processing_ms() :: :"llm.multimodal.processing_ms"
  def llm_multimodal_processing_ms, do: :"llm.multimodal.processing_ms"

  @doc """
  Token count of the fully rendered prompt after variable substitution.

  Attribute: `llm.prompt.rendered_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `150`, `512`, `2048`
  """
  @spec llm_prompt_rendered_tokens() :: :"llm.prompt.rendered_tokens"
  def llm_prompt_rendered_tokens, do: :"llm.prompt.rendered_tokens"

  @doc """
  Identifier of the prompt template used to generate the LLM request.

  Attribute: `llm.prompt.template_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `tmpl-healing-v2`, `system-prompt-001`
  """
  @spec llm_prompt_template_id() :: :"llm.prompt.template_id"
  def llm_prompt_template_id, do: :"llm.prompt.template_id"

  @doc """
  Number of template variables substituted in the rendered prompt.

  Attribute: `llm.prompt.variable_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `3`, `10`
  """
  @spec llm_prompt_variable_count() :: :"llm.prompt.variable_count"
  def llm_prompt_variable_count, do: :"llm.prompt.variable_count"

  @doc """
  Version of the prompt template.

  Attribute: `llm.prompt.version`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0.0`, `2.3.1`
  """
  @spec llm_prompt_version() :: :"llm.prompt.version"
  def llm_prompt_version, do: :"llm.prompt.version"

  @doc """
  The LLM provider name.

  Attribute: `llm.provider`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `anthropic`, `openai`, `google`
  """
  @spec llm_provider() :: :"llm.provider"
  def llm_provider, do: :"llm.provider"

  @doc """
  Total token count of the retrieved context injected into the LLM prompt.

  Attribute: `llm.rag.context_window_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `1024`, `4096`
  """
  @spec llm_rag_context_window_tokens() :: :"llm.rag.context_window_tokens"
  def llm_rag_context_window_tokens, do: :"llm.rag.context_window_tokens"

  @doc """
  Number of documents retrieved (top-k) in the RAG retrieval step.

  Attribute: `llm.rag.retrieval_k`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `5`, `10`, `20`
  """
  @spec llm_rag_retrieval_k() :: :"llm.rag.retrieval_k"
  def llm_rag_retrieval_k, do: :"llm.rag.retrieval_k"

  @doc """
  Minimum similarity score [0.0, 1.0] for retrieved documents to be included.

  Attribute: `llm.rag.similarity_threshold`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.5`, `0.7`, `0.9`
  """
  @spec llm_rag_similarity_threshold() :: :"llm.rag.similarity_threshold"
  def llm_rag_similarity_threshold, do: :"llm.rag.similarity_threshold"

  @doc """
  Unique identifier for this LLM API request, from the provider response.

  Attribute: `llm.request.id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `chatcmpl-abc123`, `msg_01XFDUDYJgAACzvnptvVoYEL`
  """
  @spec llm_request_id() :: :"llm.request.id"
  def llm_request_id, do: :"llm.request.id"

  @doc """
  Number of retry attempts for this LLM request (e.g., due to rate limits or errors).

  Attribute: `llm.retry.count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `3`
  """
  @spec llm_retry_count() :: :"llm.retry.count"
  def llm_retry_count, do: :"llm.retry.count"

  @doc """
  Safety score for this LLM response, range [0.0, 1.0]. Lower = less safe.

  Attribute: `llm.safety.score`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.95`, `0.72`, `0.4`
  """
  @spec llm_safety_score() :: :"llm.safety.score"
  def llm_safety_score, do: :"llm.safety.score"

  @doc """
  Maximum number of tokens to generate in the LLM response.

  Attribute: `llm.sampling.max_tokens`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `256`, `1024`, `4096`
  """
  @spec llm_sampling_max_tokens() :: :"llm.sampling.max_tokens"
  def llm_sampling_max_tokens, do: :"llm.sampling.max_tokens"

  @doc """
  Random seed for deterministic LLM sampling. -1 means non-deterministic.

  Attribute: `llm.sampling.seed`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `-1`, `0`, `42`, `12345`
  """
  @spec llm_sampling_seed() :: :"llm.sampling.seed"
  def llm_sampling_seed, do: :"llm.sampling.seed"

  @doc """
  LLM sampling temperature controlling output randomness, range [0.0, 2.0].

  Attribute: `llm.sampling.temperature`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.7`, `1.0`, `2.0`
  """
  @spec llm_sampling_temperature() :: :"llm.sampling.temperature"
  def llm_sampling_temperature, do: :"llm.sampling.temperature"

  @doc """
  Nucleus sampling probability threshold, range [0.0, 1.0].

  Attribute: `llm.sampling.top_p`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.9`, `0.95`, `1.0`
  """
  @spec llm_sampling_top_p() :: :"llm.sampling.top_p"
  def llm_sampling_top_p, do: :"llm.sampling.top_p"

  @doc """
  The reason the LLM stopped generating tokens.

  Attribute: `llm.stop_reason`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `end_turn`, `max_tokens`, `stop_sequence`
  """
  @spec llm_stop_reason() :: :"llm.stop_reason"
  def llm_stop_reason, do: :"llm.stop_reason"

  @doc """
  Enumerated values for `llm.stop_reason`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `max_tokens` | `"max_tokens"` | max_tokens |
  | `stop_sequence` | `"stop_sequence"` | stop_sequence |
  | `length` | `"length"` | length |
  | `end_turn` | `"end_turn"` | end_turn |
  | `tool_use` | `"tool_use"` | tool_use |
  """
  @spec llm_stop_reason_values() :: %{
    max_tokens: :max_tokens,
    stop_sequence: :stop_sequence,
    length: :length,
    end_turn: :end_turn,
    tool_use: :tool_use
  }
  def llm_stop_reason_values do
    %{
      max_tokens: :max_tokens,
      stop_sequence: :stop_sequence,
      length: :length,
      end_turn: :end_turn,
      tool_use: :tool_use
    }
  end

  defmodule LlmStopReasonValues do
    @moduledoc """
    Typed constants for the `llm.stop_reason` attribute.
    """

    @doc "max_tokens"
    @spec max_tokens() :: :max_tokens
    def max_tokens, do: :max_tokens

    @doc "stop_sequence"
    @spec stop_sequence() :: :stop_sequence
    def stop_sequence, do: :stop_sequence

    @doc "length"
    @spec length() :: :length
    def length, do: :length

    @doc "end_turn"
    @spec end_turn() :: :end_turn
    def end_turn, do: :end_turn

    @doc "tool_use"
    @spec tool_use() :: :tool_use
    def tool_use, do: :tool_use

  end

  @doc """
  Number of streaming chunks received for a streaming LLM response.

  Attribute: `llm.streaming.chunk_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `10`, `50`, `200`
  """
  @spec llm_streaming_chunk_count() :: :"llm.streaming.chunk_count"
  def llm_streaming_chunk_count, do: :"llm.streaming.chunk_count"

  @doc """
  Whether the streaming response completed successfully without interruption.

  Attribute: `llm.streaming.complete`
  Type: `boolean`
  Stability: `development`
  Requirement: `recommended`
  """
  @spec llm_streaming_complete() :: :"llm.streaming.complete"
  def llm_streaming_complete, do: :"llm.streaming.complete"

  @doc """
  Time to first token in milliseconds (TTFT) for streaming responses.

  Attribute: `llm.streaming.first_token_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `150`, `500`, `2000`
  """
  @spec llm_streaming_first_token_ms() :: :"llm.streaming.first_token_ms"
  def llm_streaming_first_token_ms, do: :"llm.streaming.first_token_ms"

  @doc """
  Average token generation rate for streaming responses.

  Attribute: `llm.streaming.tokens_per_second`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `25.5`, `50.0`, `100.0`
  """
  @spec llm_streaming_tokens_per_second() :: :"llm.streaming.tokens_per_second"
  def llm_streaming_tokens_per_second, do: :"llm.streaming.tokens_per_second"

  @doc """
  Output format enforced by the structured output schema.

  Attribute: `llm.structured_output.format`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `json`, `yaml`
  """
  @spec llm_structured_output_format() :: :"llm.structured_output.format"
  def llm_structured_output_format, do: :"llm.structured_output.format"

  @doc """
  Enumerated values for `llm.structured_output.format`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `json` | `"json"` | json |
  | `xml` | `"xml"` | xml |
  | `yaml` | `"yaml"` | yaml |
  | `markdown` | `"markdown"` | markdown |
  """
  @spec llm_structured_output_format_values() :: %{
    json: :json,
    xml: :xml,
    yaml: :yaml,
    markdown: :markdown
  }
  def llm_structured_output_format_values do
    %{
      json: :json,
      xml: :xml,
      yaml: :yaml,
      markdown: :markdown
    }
  end

  defmodule LlmStructuredOutputFormatValues do
    @moduledoc """
    Typed constants for the `llm.structured_output.format` attribute.
    """

    @doc "json"
    @spec json() :: :json
    def json, do: :json

    @doc "xml"
    @spec xml() :: :xml
    def xml, do: :xml

    @doc "yaml"
    @spec yaml() :: :yaml
    def yaml, do: :yaml

    @doc "markdown"
    @spec markdown() :: :markdown
    def markdown, do: :markdown

  end

  @doc """
  Identifier of the JSON schema used to validate the structured output.

  Attribute: `llm.structured_output.schema_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `schema-user-v2`, `invoice-extraction-v1`
  """
  @spec llm_structured_output_schema_id() :: :"llm.structured_output.schema_id"
  def llm_structured_output_schema_id, do: :"llm.structured_output.schema_id"

  @doc """
  Time in milliseconds to validate the LLM output against the structured schema.

  Attribute: `llm.structured_output.validation_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `25`, `100`
  """
  @spec llm_structured_output_validation_ms() :: :"llm.structured_output.validation_ms"
  def llm_structured_output_validation_ms, do: :"llm.structured_output.validation_ms"

  @doc """
  Sampling temperature used for the LLM inference (0.0 = deterministic).

  Attribute: `llm.temperature`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.0`, `0.7`, `1.0`
  """
  @spec llm_temperature() :: :"llm.temperature"
  def llm_temperature, do: :"llm.temperature"

  @doc """
  Remaining token budget for the current LLM session or context window.

  Attribute: `llm.token.budget_remaining`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `2048`, `8192`, `32000`
  """
  @spec llm_token_budget_remaining() :: :"llm.token.budget_remaining"
  def llm_token_budget_remaining, do: :"llm.token.budget_remaining"

  @doc """
  Number of tokens in the LLM completion/output response.

  Attribute: `llm.token.completion_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `64`, `256`, `1024`
  """
  @spec llm_token_completion_count() :: :"llm.token.completion_count"
  def llm_token_completion_count, do: :"llm.token.completion_count"

  @doc """
  Number of input (prompt) tokens sent to the LLM.

  Attribute: `llm.token.input`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `512`, `2048`, `8192`
  """
  @spec llm_token_input() :: :"llm.token.input"
  def llm_token_input, do: :"llm.token.input"

  @doc """
  Number of output (completion) tokens received from the LLM.

  Attribute: `llm.token.output`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `1024`, `4096`
  """
  @spec llm_token_output() :: :"llm.token.output"
  def llm_token_output, do: :"llm.token.output"

  @doc """
  Number of tokens in the prompt/input sent to the LLM.

  Attribute: `llm.token.prompt_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `128`, `512`, `2048`
  """
  @spec llm_token_prompt_count() :: :"llm.token.prompt_count"
  def llm_token_prompt_count, do: :"llm.token.prompt_count"

  @doc """
  Number of tool calls made during this LLM inference.

  Attribute: `llm.tool.call_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0`, `1`, `5`
  """
  @spec llm_tool_call_count() :: :"llm.tool.call_count"
  def llm_tool_call_count, do: :"llm.tool.call_count"

  @doc """
  Number of orchestration steps executed in the LLM tool pipeline.

  Attribute: `llm.tool.orchestration.step_count`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1`, `3`, `10`
  """
  @spec llm_tool_orchestration_step_count() :: :"llm.tool.orchestration.step_count"
  def llm_tool_orchestration_step_count, do: :"llm.tool.orchestration.step_count"

  @doc """
  Strategy used to orchestrate multiple LLM tool calls.

  Attribute: `llm.tool.orchestration.strategy`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `sequential`, `parallel`
  """
  @spec llm_tool_orchestration_strategy() :: :"llm.tool.orchestration.strategy"
  def llm_tool_orchestration_strategy, do: :"llm.tool.orchestration.strategy"

  @doc """
  Enumerated values for `llm.tool.orchestration.strategy`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `sequential` | `"sequential"` | sequential |
  | `parallel` | `"parallel"` | parallel |
  | `conditional` | `"conditional"` | conditional |
  | `retry` | `"retry"` | retry |
  """
  @spec llm_tool_orchestration_strategy_values() :: %{
    sequential: :sequential,
    parallel: :parallel,
    conditional: :conditional,
    retry: :retry
  }
  def llm_tool_orchestration_strategy_values do
    %{
      sequential: :sequential,
      parallel: :parallel,
      conditional: :conditional,
      retry: :retry
    }
  end

  defmodule LlmToolOrchestrationStrategyValues do
    @moduledoc """
    Typed constants for the `llm.tool.orchestration.strategy` attribute.
    """

    @doc "sequential"
    @spec sequential() :: :sequential
    def sequential, do: :sequential

    @doc "parallel"
    @spec parallel() :: :parallel
    def parallel, do: :parallel

    @doc "conditional"
    @spec conditional() :: :conditional
    def conditional, do: :conditional

    @doc "retry"
    @spec retry() :: :retry
    def retry, do: :retry

  end

  @doc """
  Fraction of orchestration steps that completed successfully [0.0, 1.0].

  Attribute: `llm.tool.orchestration.success_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `0.8`, `0.95`, `1.0`
  """
  @spec llm_tool_orchestration_success_rate() :: :"llm.tool.orchestration.success_rate"
  def llm_tool_orchestration_success_rate, do: :"llm.tool.orchestration.success_rate"

  @doc """
  Duration in milliseconds of the LLM response validation.

  Attribute: `llm.validation.duration_ms`
  Type: `int`
  Stability: `development`
  Requirement: `recommended`
  Examples: `5`, `25`
  """
  @spec llm_validation_duration_ms() :: :"llm.validation.duration_ms"
  def llm_validation_duration_ms, do: :"llm.validation.duration_ms"

  @doc """
  Category of validation error encountered when validating the LLM response.

  Attribute: `llm.validation.error_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `format`, `required`
  """
  @spec llm_validation_error_type() :: :"llm.validation.error_type"
  def llm_validation_error_type, do: :"llm.validation.error_type"

  @doc """
  Enumerated values for `llm.validation.error_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `format` | `"format"` | format |
  | `type_mismatch` | `"type"` | type |
  | `required_field` | `"required"` | required |
  | `enum_violation` | `"enum"` | enum |
  """
  @spec llm_validation_error_type_values() :: %{
    format: :format,
    type_mismatch: :type,
    required_field: :required,
    enum_violation: :enum
  }
  def llm_validation_error_type_values do
    %{
      format: :format,
      type_mismatch: :type,
      required_field: :required,
      enum_violation: :enum
    }
  end

  defmodule LlmValidationErrorTypeValues do
    @moduledoc """
    Typed constants for the `llm.validation.error_type` attribute.
    """

    @doc "format"
    @spec format() :: :format
    def format, do: :format

    @doc "type"
    @spec type_mismatch() :: :type
    def type_mismatch, do: :type

    @doc "required"
    @spec required_field() :: :required
    def required_field, do: :required

    @doc "enum"
    @spec enum_violation() :: :enum
    def enum_violation, do: :enum

  end

  @doc """
  Fraction of validation checks that passed, range [0.0, 1.0].

  Attribute: `llm.validation.pass_rate`
  Type: `double`
  Stability: `development`
  Requirement: `recommended`
  Examples: `1.0`, `0.85`
  """
  @spec llm_validation_pass_rate() :: :"llm.validation.pass_rate"
  def llm_validation_pass_rate, do: :"llm.validation.pass_rate"

  @doc """
  Identifier of the JSON schema used to validate the LLM response.

  Attribute: `llm.validation.schema_id`
  Type: `string`
  Stability: `development`
  Requirement: `recommended`
  Examples: `schema-v1`, `output-contract-abc`
  """
  @spec llm_validation_schema_id() :: :"llm.validation.schema_id"
  def llm_validation_schema_id, do: :"llm.validation.schema_id"

end