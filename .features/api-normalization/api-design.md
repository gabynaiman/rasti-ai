# Diseño de la API pública — `generate_text` / `Agent`

Refinamiento de la propuesta de entry points. Conclusión previa: esta API **no es la Opción A**
(fachada barata). El momento en que `messages:` acepta roles genéricos, el modelo canónico de
mensajes se vuelve obligatorio — o sea, arrastra la Opción B por construcción. Eso es bueno: evita
construir A con mensajes provider-specific para tirarlo después.

---

## 1. Firmas propuestas (revisadas)

```ruby
module Rasti
  module AI

    def self.generate_text(provider: nil, model: nil,
                           prompt: nil, messages: nil, system: nil,
                           tools: [], mcp_servers: {}, tool_choice: nil, max_steps: 1,
                           json_schema: nil, thinking: nil, max_tokens: nil, temperature: nil,
                           api_key: nil, usage_tracker: nil, logger: nil,
                           http_connect_timeout: nil, http_read_timeout: nil, http_max_retries: nil,
                           provider_options: {})
    end

    def self.generate_object(schema:, **options)  # generate_text + json_schema + result.object
    end

  end

  class AI::Agent

    def initialize(provider: nil, model: nil, state: nil,
                   system: nil, tools: [], mcp_servers: {}, tool_choice: nil, max_steps: 20,
                   json_schema: nil, thinking: nil, max_tokens: nil, temperature: nil,
                   api_key: nil, usage_tracker: nil, logger: nil,
                   http_connect_timeout: nil, http_read_timeout: nil, http_max_retries: nil,
                   provider_options: {})
    end

    def call(prompt)  # => Result
    end

  end
end
```

`Rasti::AI.create_agent(...)` queda como alias de `Agent.new` si se quiere simetría con
`generate_text`, pero `Agent.new` es el idioma Ruby y debería ser el camino documentado.

---

## 2. Decisiones y por qué

### 2.1 `prompt:` además de `messages:`

El caso mayoritario es un string. Que la firma mínima sea
`generate_text prompt: 'who is the best player'` vale más que la pureza de un solo parámetro.
`messages:` queda para control total. Son mutuamente excluyentes (`ArgumentError` si vienen los dos).

### 2.2 `system:` como parámetro, no como mensaje

Anthropic y Gemini ponen el system prompt **fuera** del array de mensajes (`system`,
`system_instruction`). Modelarlo como `{role: :system}` dentro de `messages:` obliga a que cada
adapter lo extraiga del array. Mejor que sea un campo del `Request`. Igual se acepta un mensaje con
`role: :system` en `messages:` y se normaliza hacia `system:` al construir el `Request`.

Esto además deja claro qué pasa con `state.context`: es el `system` del agente. Sugerencia:
`Agent.new(system:)` como nombre nuevo, `state.context` sigue funcionando como fuente si no se pasa
`system:`.

### 2.3 `provider:` acepta Symbol **o** instancia

Con `api_key:`, `usage_tracker:`, timeouts y `logger:` como kwargs planos, la firma tiene 8
parámetros que son de *transporte*, no de generación. Sirve para el caso simple, pero repetirlos en
cada llamada es ruido. Solución: que `provider:` acepte las dos formas.

```ruby
# Simple: símbolo, resuelve api_key y defaults de la config global
Rasti::AI.generate_text provider: :anthropic, model: 'claude-sonnet-4-5', prompt: '...'

# Reusable / multi-tenant: instancia con su propia credencial y transporte
provider = Rasti::AI.provider :anthropic, api_key: tenant.anthropic_key,
                                          usage_tracker: ->(u) { tenant.track u },
                                          http_read_timeout: 300

Rasti::AI.generate_text provider: provider, model: 'claude-sonnet-4-5', prompt: '...'
Rasti::AI::Agent.new provider: provider, model: 'claude-sonnet-4-5', tools: tools
```

Los kwargs planos (`api_key:`, `usage_tracker:`, ...) siguen existiendo como atajo y se usan para
construir el provider internamente. Un provider explícito los ignora (o lanza `ArgumentError` si se
mezclan — a definir).

Beneficio concreto: `usage_tracker` per-session/per-tenant deja de necesitar un `Client` custom, que
es la única forma de hacerlo hoy.

### 2.4 `provider_options:` en vez de `**opts`

Un `**opts` que se reenvía al body es cómodo pero silencioso: `temparature: 0.5` no falla, se manda y
el provider lo ignora. Propuesta:

- Parámetros **normalizados** explícitos: `thinking`, `max_tokens`, `temperature`, `tool_choice`,
  `max_steps`, `json_schema`. Cada adapter los traduce a su dialecto (como hoy con `thinking`).
- `provider_options:` — hash que se mergea crudo en el body del provider, escape hatch documentado.
  Equivalente a `providerOptions` de Vercel.

Cualquier kwarg desconocido debe explotar. Sin `**opts` en la firma pública.

### 2.5 Valor de retorno: `Result`, no String

Hoy `Assistant#call` devuelve un String, y eso obliga a un `Client` custom para conocer el usage y
hace inaccesible el `finish_reason` y los tool calls ejecutados.

```ruby
result = Rasti::AI.generate_text provider: :openai, prompt: 'who is the best player'

result.text           # => 'Lionel Messi'
result.object         # => Hash parseado, cuando hay json_schema (hoy: hay que hacer JSON.parse a mano)
result.usage          # => Usage (o Array de Usage si hubo varios pasos)
result.messages       # => historial canónico completo
result.tool_calls     # => [Part::ToolCall] ejecutados
result.steps          # => [Step] request/response por iteración del loop
result.finish_reason  # => :stop | :tool_calls | :max_steps | :length
result.raw            # => payload crudo del último response
```

Compatibilidad: `Result#to_s` devuelve `text`. Así `assistant.call('...')` interpolado en un string
o comparado con `==` sigue andando en la mayoría de los usos existentes. `Result#to_str` también, si
se quiere coerción implícita completa (a evaluar: puede enmascarar errores).

### 2.6 `json_schema:` acepta Hash **o** `Rasti::Form`

`ToolSerializer` ya convierte Forms a JSON Schema. Aceptar un Form cierra el círculo y evita escribir
schemas a mano. El Hash crudo actual sigue soportado.

`generate_object(schema:)` es el azúcar: valida que haya schema y expone `result.object` ya parseado.

### 2.7 `max_steps:`

Hoy `Assistant#call` es un `loop do` sin tope: un modelo que insiste en llamar tools cuelga el
proceso. `max_steps` con `finish_reason: :max_steps` cierra ese agujero. Default: `1` en
`generate_text` (one-shot explícito, y si hay tools se sube a mano) y `20` en `Agent`.

### 2.8 `state:` en el agente

Debe ser opcional (default `AssistantState.new`). Cuando el modelo canónico esté en su lugar,
`state.messages` es serializable a JSON y un thread se puede persistir y reanudar con otro provider.
Ese es el entregable que justifica el major.

Renombre sugerido: `AssistantState` → `Session` (o `Thread`), con alias de compatibilidad.

### 2.9 Streaming: no hacerlo ahora, no bloquearlo

`Provider#decode(raw_body)` sobre la respuesta completa no impide agregar después
`Provider#decode_stream(chunks)` que emita los mismos `Part` de forma incremental. Basta con no
asumir en el `Result` que todo llegó de una sola pieza. No entra en este alcance.

---

## 3. Orden de implementación

La API pública se define primero (este documento) pero se **expone al final**, sobre base sólida.

| Paso | Alcance | Release |
|---|---|---|
| 1 | Modelo canónico: `Message`, `Part::*`, `ToolDefinition`, `Request`, `Response`, `Result`, `Step`. Base `Provider` con `encode`/`decode`/`parse_usage`/`endpoint`. Motor `Engine` con el loop (el `call` actual, sin template methods). Port del adapter OpenAI. Los `<Provider>::Assistant` actuales siguen funcionando sobre el motor nuevo vía shim. | interno |
| 2 | Port de Gemini, Anthropic, OpenRouter, HuaweiMaaS. Se borra: 5 `roles.rb`, `sanitize_schema` duplicado, los `Client` por provider (queda uno solo con auth pluggable), 12 template methods. | interno |
| 3 | Registry + `Rasti::AI.provider`, `generate_text`, `generate_object`, `Agent`, config `default_provider` / `default_model`. Alias de compatibilidad. README nuevo. | 4.0.0 |

Cada paso deja la suite verde. Los fixtures ERB de `spec/resources/` se reutilizan tal cual: pasan a
testear `encode`/`decode` como funciones puras, sin WebMock, y el loop se testea una sola vez con un
provider fake.

---

## 4. Puntos abiertos

1. ¿`<Provider>::Client` sobrevive como API pública (shim `chat_completions`/`messages`/
   `generate_content`) o se deprecia en 4.0?
2. ¿`Result#to_str` (coerción implícita) o sólo `to_s`? `to_str` maximiza compatibilidad pero puede
   ocultar bugs.
3. ¿`Agent` reemplaza a `Assistant` con alias, o conviven documentados?
4. Mezclar `provider:` instancia con kwargs de transporte: ¿ignorar en silencio o `ArgumentError`?
5. `usage` en el `Result` con varios pasos: ¿array de `Usage` o un `Usage` agregado (+ `#usages`)?
