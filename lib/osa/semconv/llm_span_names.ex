defmodule OpenTelemetry.SemConv.Incubating.LlmSpanNames do
  @moduledoc """
  Llm semantic convention span names.

  Namespace: `llm`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  LLM adapter application — applying a parameter-efficient fine-tuning adapter to customize a base model.

  Span: `span.llm.adapter.apply`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_adapter_apply() :: String.t()
  def llm_adapter_apply, do: "llm.adapter.apply"

  @doc """
  LLM batch inference job — processing multiple requests in a single batch for efficiency.

  Span: `span.llm.batch.run`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_batch_run() :: String.t()
  def llm_batch_run, do: "llm.batch.run"

  @doc """
  LLM response cache lookup — checks if a cached response exists for the given prompt hash.

  Span: `span.llm.cache.lookup`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_cache_lookup() :: String.t()
  def llm_cache_lookup, do: "llm.cache.lookup"

  @doc """
  Executing chain-of-thought reasoning — multi-step LLM inference with intermediate reasoning.

  Span: `span.llm.chain_of_thought`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_chain_of_thought() :: String.t()
  def llm_chain_of_thought, do: "llm.chain_of_thought"

  @doc """
  Context window management — handles overflow by applying the configured strategy.

  Span: `span.llm.context.manage`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_context_manage() :: String.t()
  def llm_context_manage, do: "llm.context.manage"

  @doc """
  Recording cost for a completed LLM inference — captures input/output token costs.

  Span: `span.llm.cost.record`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_cost_record() :: String.t()
  def llm_cost_record, do: "llm.cost.record"

  @doc """
  Knowledge distillation training — transferring knowledge from teacher to student model.

  Span: `span.llm.distillation.train`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_distillation_train() :: String.t()
  def llm_distillation_train, do: "llm.distillation.train"

  @doc """
  LLM embedding generation — converting text input into dense vector representations for semantic search or retrieval.

  Span: `span.llm.embedding.generate`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_embedding_generate() :: String.t()
  def llm_embedding_generate, do: "llm.embedding.generate"

  @doc """
  Evaluating an LLM response quality using a scoring rubric.

  Span: `span.llm.evaluation`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_evaluation() :: String.t()
  def llm_evaluation, do: "llm.evaluation"

  @doc """
  Few-shot example retrieval — selecting and ranking examples for in-context learning.

  Span: `span.llm.few_shot.retrieve`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_few_shot_retrieve() :: String.t()
  def llm_few_shot_retrieve, do: "llm.few_shot.retrieve"

  @doc """
  LLM fine-tuning job execution — training a language model on domain-specific data.

  Span: `span.llm.finetune.run`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_finetune_run() :: String.t()
  def llm_finetune_run, do: "llm.finetune.run"

  @doc """
  LLM function call routing — directing a function call from LLM output to the appropriate handler.

  Span: `span.llm.function_call.route`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_function_call_route() :: String.t()
  def llm_function_call_route, do: "llm.function_call.route"

  @doc """
  Evaluating LLM safety guardrails on a request or response.

  Span: `span.llm.guardrail.check`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_guardrail_check() :: String.t()
  def llm_guardrail_check, do: "llm.guardrail.check"

  @doc """
  A single LLM inference call — prompt sent, completion received.

  Span: `span.llm.inference`
  Kind: `client`
  Stability: `development`
  """
  @spec llm_inference() :: String.t()
  def llm_inference, do: "llm.inference"

  @doc """
  LoRA fine-tuning run — applies Low-Rank Adaptation to update a pre-trained model efficiently.

  Span: `span.llm.lora.train`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_lora_train() :: String.t()
  def llm_lora_train, do: "llm.lora.train"

  @doc """
  Multi-modal LLM processing — handling inputs that combine text with images, audio, video, or documents.

  Span: `span.llm.multimodal.process`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_multimodal_process() :: String.t()
  def llm_multimodal_process, do: "llm.multimodal.process"

  @doc """
  Rendering a prompt template — substituting variables to produce the final LLM request payload.

  Span: `span.llm.prompt.render`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_prompt_render() :: String.t()
  def llm_prompt_render, do: "llm.prompt.render"

  @doc """
  Retrieval-augmented generation retrieval step — fetching relevant documents from a vector store.

  Span: `span.llm.rag.retrieve`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_rag_retrieve() :: String.t()
  def llm_rag_retrieve, do: "llm.rag.retrieve"

  @doc """
  LLM response validation — checking a model output against a JSON schema or contract for type safety and completeness.

  Span: `span.llm.response.validate`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_response_validate() :: String.t()
  def llm_response_validate, do: "llm.response.validate"

  @doc """
  Configuration of LLM sampling parameters for a generation request.

  Span: `span.llm.sampling.configure`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_sampling_configure() :: String.t()
  def llm_sampling_configure, do: "llm.sampling.configure"

  @doc """
  Completion of a streaming LLM response — tracks TTFT, throughput, and chunk delivery.

  Span: `span.llm.streaming.complete`
  Kind: `client`
  Stability: `development`
  """
  @spec llm_streaming_complete() :: String.t()
  def llm_streaming_complete, do: "llm.streaming.complete"

  @doc """
  Start of a streaming LLM response — first token received.

  Span: `span.llm.streaming_start`
  Kind: `client`
  Stability: `development`
  """
  @spec llm_streaming_start() :: String.t()
  def llm_streaming_start, do: "llm.streaming_start"

  @doc """
  Structured output generation — LLM produces output conforming to a defined schema.

  Span: `span.llm.structured_output.generate`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_structured_output_generate() :: String.t()
  def llm_structured_output_generate, do: "llm.structured_output.generate"

  @doc """
  Token budget enforcement for an LLM session — tracks prompt/completion token usage.

  Span: `span.llm.token.budget`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_token_budget() :: String.t()
  def llm_token_budget, do: "llm.token.budget"

  @doc """
  LLM tool orchestration — coordinates multiple tool calls according to a defined strategy.

  Span: `span.llm.tool.orchestrate`
  Kind: `internal`
  Stability: `development`
  """
  @spec llm_tool_orchestrate() :: String.t()
  def llm_tool_orchestrate, do: "llm.tool.orchestrate"

  @doc """
  All span names in this namespace.
  """
  @spec all() :: [String.t()]
  def all do
    [
      llm_adapter_apply(),
      llm_batch_run(),
      llm_cache_lookup(),
      llm_chain_of_thought(),
      llm_context_manage(),
      llm_cost_record(),
      llm_distillation_train(),
      llm_embedding_generate(),
      llm_evaluation(),
      llm_few_shot_retrieve(),
      llm_finetune_run(),
      llm_function_call_route(),
      llm_guardrail_check(),
      llm_inference(),
      llm_lora_train(),
      llm_multimodal_process(),
      llm_prompt_render(),
      llm_rag_retrieve(),
      llm_response_validate(),
      llm_sampling_configure(),
      llm_streaming_complete(),
      llm_streaming_start(),
      llm_structured_output_generate(),
      llm_token_budget(),
      llm_tool_orchestrate()
    ]
  end
end