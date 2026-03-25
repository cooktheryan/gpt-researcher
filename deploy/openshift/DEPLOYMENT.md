# GPT Researcher - OpenShift Deployment

## Prerequisites

- OpenShift 4.x cluster with `oc` CLI authenticated
- Image pushed: `quay.io/opendatahub/odh-gpt-researcher:latest`

## 1. Create the Secret

Create the secret manually before deploying. Include `OPENAI_BASE_URL` if using a custom endpoint.

```bash
oc create secret generic gpt-researcher \
  --from-literal=OPENAI_API_KEY=<key> \
  --from-literal=TAVILY_API_KEY=<key> \
  --from-literal=OPENAI_BASE_URL=<url>
```

## 2. Deploy

```bash
oc apply -k deploy/openshift/
```

## 3. Verify

```bash
oc get pods -l app.kubernetes.io/name=gpt-researcher
oc logs deployment/gpt-researcher
```

## Access

The API is available within the cluster at:

```
http://gpt-researcher.<namespace>.svc.cluster.local:8000
```

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| Deployment | `gpt-researcher` | FastAPI backend (1 replica, UID 1001) |
| Service | `gpt-researcher` | ClusterIP on port 8000 |
| PVC | `gpt-researcher-outputs` | 5Gi - research output storage |
| PVC | `gpt-researcher-my-docs` | 5Gi - input document storage |

## Volume Mounts

| Mount Path | Source | Description |
|------------|--------|-------------|
| `/opt/app-root/src/outputs` | PVC | Persistent research results |
| `/opt/app-root/src/my-docs` | PVC | Persistent input documents |
| `/opt/app-root/src/logs` | emptyDir | Ephemeral logs (also streams to stdout) |

## Security

- Runs as UID 1001 (non-root), compatible with `restricted-v2` SCC
- All capabilities dropped, no privilege escalation
- SeccompProfile set to `RuntimeDefault`

## Using Alternative LLM Providers

GPT Researcher is not limited to OpenAI. It supports many LLM providers via the
`FAST_LLM`, `SMART_LLM`, and `STRATEGIC_LLM` env vars using a `provider:model` format.
Add these to your secret to override the defaults.

### Custom OpenAI-Compatible API

Any service that exposes an OpenAI-compatible API (vLLM, llama.cpp, Ollama, etc.):

```bash
oc create secret generic gpt-researcher \
  --from-literal=OPENAI_API_KEY=<key> \
  --from-literal=OPENAI_BASE_URL=http://my-llm-service:8000/v1 \
  --from-literal=TAVILY_API_KEY=<key> \
  --from-literal=FAST_LLM=openai:my-model \
  --from-literal=SMART_LLM=openai:my-model \
  --from-literal=STRATEGIC_LLM=openai:my-model
```

### Supported Providers

| Provider | Example `SMART_LLM` | Extra Secret Keys |
|----------|---------------------|-------------------|
| OpenAI | `openai:gpt-5` | `OPENAI_API_KEY` |
| Custom OpenAI-compatible | `openai:my-model` | `OPENAI_API_KEY`, `OPENAI_BASE_URL` |
| Ollama | `ollama:llama3` | `OLLAMA_BASE_URL` |
| Anthropic | `anthropic:claude-3-opus-20240229` | `ANTHROPIC_API_KEY` |
| Azure OpenAI | `azure_openai:gpt-4o` | `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, `OPENAI_API_VERSION` |
| Google Gemini | `google_genai:gemini-1.5-pro` | `GOOGLE_API_KEY` |
| Groq | `groq:Mixtral-8x7b-32768` | `GROQ_API_KEY` |
| Mistral AI | `mistralai:mistral-large-latest` | `MISTRAL_API_KEY` |
| Together AI | `together:meta-llama/Llama-3-70b-chat-hf` | `TOGETHER_API_KEY` |
| DeepSeek | `deepseek:deepseek-chat` | `DEEPSEEK_API_KEY` |
| Bedrock | `bedrock:anthropic.claude-3-sonnet-20240229-v1:0` | AWS credentials |
| vLLM | `vllm_openai:Qwen/Qwen3-8B-AWQ` | `VLLM_OPENAI_API_KEY`, `VLLM_OPENAI_API_BASE` |
| LiteLLM | `litellm:perplexity/pplx-70b-chat` | varies |

### Granite Models (with Ollama)

Granite models have dedicated prompt formatting support:

```bash
oc create secret generic gpt-researcher \
  --from-literal=OPENAI_API_KEY=unused \
  --from-literal=TAVILY_API_KEY=<key> \
  --from-literal=OLLAMA_BASE_URL=http://ollama-service:11434 \
  --from-literal=FAST_LLM=ollama:granite3.3:2b \
  --from-literal=SMART_LLM=ollama:granite3.3:8b \
  --from-literal=STRATEGIC_LLM=ollama:granite3.3:8b \
  --from-literal=PROMPT_FAMILY=granite
```

### Embedding Providers

Embeddings are configured separately via the `EMBEDDING` env var:

| Provider | Example `EMBEDDING` |
|----------|---------------------|
| OpenAI | `openai:text-embedding-3-small` |
| Ollama | `ollama:nomic-embed-text` |
| Google | `google_genai:models/text-embedding-004` |
| Cohere | `cohere:embed-english-v3.0` |
| HuggingFace | `huggingface:sentence-transformers/all-MiniLM-L6-v2` |
| Bedrock | `bedrock:amazon.titan-embed-text-v2:0` |

## Cleanup

```bash
oc delete -k deploy/openshift/
oc delete secret gpt-researcher
```
