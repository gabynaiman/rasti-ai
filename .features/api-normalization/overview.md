# Normalización de la API de Rasti::AI

Objetivo: poder elegir provider y modelo **por configuración o por parámetro**, y usar la gema
para (a) pegarle directo a un modelo y obtener una respuesta, o (b) armar un agente con tools,
estado y structured output — sin importar el provider. Referencias de diseño: Vercel AI SDK
(`generateText({ model })`, `LanguageModelV2`) y pi (`agent`, provider/model como strings).

---

## 1. Diagnóstico: qué impide hoy la unificación

| Acoplamiento | Dónde | Consecuencia |
|---|---|---|
| Los mensajes se guardan con el shape del provider | `AssistantState#messages` + los 5 `build_*_message` | No se puede cambiar de provider en una conversación existente, ni persistir/reanudar una conversación con otro provider |
| El nombre del método de API difiere | `chat_completions` / `messages` / `generate_content` | El `Assistant` no puede hablarle a un `Client` genérico; `request_completion` es template method |
| La respuesta se parsea "in situ" | `parse_content`, `parse_tool_calls`, `finished?`, `extract_tool_call_info` | 4 de los 12 template methods son sólo "leer el JSON crudo" |
| La serialización de tools se re-envuelve por provider | `wrap_tool_serialization`, `extract_tool_name`, `sanitize_schema` duplicado en Gemini y Anthropic | Código copiado; `ToolSerializer` emite `inputSchema` y cada uno lo renombra |
| Un `Roles` por provider | 5 archivos `roles.rb` | 4 constantes con 3 valores distintos en total (`model`/`function` de Gemini) |
| La clase elegida ES el provider | `Rasti::AI::OpenAI::Assistant` | La elección de provider es una constante en el código del usuario, no un dato |

Números: de ~1.540 líneas de `lib`, los adaptadores de provider son ~700, y buena parte es
duplicación mecánica (`sanitize_schema` está literalmente dos veces).

Observación clave: **el loop de `Assistant#call` ya es universal**. Lo único que cambia por
provider es la traducción de ida (request) y de vuelta (response). Eso es exactamente la
frontera que hay que aislar.

---

## 2. Opción A — Fachada + registry (compatible, sin romper nada)

Agregar una capa de resolución arriba de lo que ya existe. Cero cambios en las clases actuales.

```ruby
Rasti::AI.configure do |config|
  config.default_provider = :anthropic
  config.default_model = 'claude-sonnet-4-5'
end

# One-shot, sin agente
Rasti::AI.generate 'who is the best player'
Rasti::AI.generate 'who is the best player', model: 'openai:gpt-4o'

# Agente, provider como dato
assistant = Rasti::AI.assistant provider: :gemini, model: 'gemini-2.0-flash', tools: tools
assistant.call 'what is the weather in Buenos Aires'
```

Implementación:

- `Rasti::AI::Providers` — registry `{openai: OpenAI::Assistant, ...}` + `register`.
- Parseo de `'provider:model'` (también `'provider/model'`) para resolver ambos de un string.
- `Rasti::AI.assistant(...)` instancia la clase concreta y devuelve el objeto actual.
- `Rasti::AI.generate(prompt, **opts)` = assistant efímero + `#call`.

| Pros | Contras |
|---|---|
| No rompe nada; release 3.2.0 | No elimina una sola línea de duplicación |
| Muy barato (~1 día con tests) | `state.messages` sigue siendo provider-specific → no se puede migrar una conversación |
| Habilita ya el "provider por config" | Agregar un provider sigue costando 12 template methods |
| Es un paso válido *hacia* B (la fachada sobrevive) | La API pública queda con dos formas de hacer lo mismo |

Veredicto: útil como **paso 1**, insuficiente como solución.

---

## 3. Opción B — Mensajes canónicos + adaptadores (la normalización real)

Un solo `Assistant`/`Agent`. El provider pasa a ser un objeto con dos responsabilidades:
codificar un request canónico y decodificar una respuesta cruda a un objeto canónico.

### 3.1 Modelo canónico

```ruby
Rasti::AI::Message   # role: :user | :assistant | :tool, parts: [...]
Rasti::AI::Part::Text        # text
Rasti::AI::Part::ToolCall    # id, name, arguments (Hash)
Rasti::AI::Part::ToolResult  # tool_call_id, name, content
Rasti::AI::Part::Reasoning   # text, signature, raw  (thinking blocks de Anthropic)
Rasti::AI::ToolDefinition    # name, description, input_schema (JSON Schema neutro)

Rasti::AI::Request   # messages, system, tools, tool_choice, model, thinking, json_schema, max_tokens
Rasti::AI::Response  # message, finish_reason, usage, raw
```

`Reasoning` con `raw` es importante: Anthropic exige devolver los thinking blocks intactos en el
turno siguiente. Guardando el `raw` del part, el encode los reinyecta sin que el modelo canónico
tenga que entender el formato.

### 3.2 Adaptador

```ruby
class Rasti::AI::Provider   # base abstracta

  def encode(request)  # => Hash (body del provider)
  def decode(raw)      # => Rasti::AI::Response
  def parse_usage(raw) # => Usage
  def endpoint(request)
  def client            # HTTP genérico, hoy Rasti::AI::Client sin subclases por provider

end
```

Cada provider implementa **4 métodos en vez de 12** (+ auth headers). El `sanitize_schema`
compartido vive en un `SchemaSanitizer` con la lista de campos permitidos como constante del
provider. `Roles` desaparece como concepto público: los roles canónicos son símbolos y cada
adapter tiene su tabla de traducción.

### 3.3 Assistant único

```ruby
class Rasti::AI::Assistant

  def initialize(provider: nil, model: nil, tools: [], mcp_servers: {}, json_schema: nil,
                 thinking: nil, state: nil, client: nil, logger: nil)

  def call(prompt)  # mismo loop de hoy, sin template methods

end
```

El loop no cambia: `messages << user` → `provider.decode(client.post(provider.endpoint, provider.encode(request)))`
→ si hay `ToolCall` parts, ejecutar y agregar `ToolResult` → si no, devolver el texto.

### 3.4 Lo que se gana

- **Portabilidad de conversación**: `state.messages` es canónico y serializable a JSON. Se puede
  persistir un thread, y reanudarlo con otro provider/modelo. Hoy es imposible.
- **Fallback / routing**: reintentar el mismo request contra otro provider ante rate limit o 5xx.
- **Un solo lugar** para tool calling, structured output y thinking.
- **Agregar provider** = 1 archivo, ~4 métodos.
- **Testing**: se puede testear el loop con un `Provider` fake, sin WebMock, y testear cada
  adapter como función pura `encode/decode` contra los fixtures ERB que ya existen.

### 3.5 Costo y compatibilidad

Rotura real y única: el shape de `state.messages`. Todo lo demás se puede preservar:

```ruby
module Rasti::AI::OpenAI
  class Assistant < Rasti::AI::Assistant
    def initialize(**options)
      super(**options, provider: :open_ai)
    end
  end
end
```

`Rasti::AI::OpenAI::Client` se puede mantener como shim (`chat_completions` → encode/post) para
quien lo use directo, o marcarlo deprecado. Los `Roles` se pueden dejar como constantes vivas.

Es un **major (4.0.0)** por el cambio de `state.messages`, con las clases por provider intactas
como alias. Esfuerzo estimado: 3-5 días incluyendo migración de specs.

---

## 4. Opción C — API funcional estilo Vercel/pi encima de B

Con B en su lugar, la superficie pública se puede rediseñar para que el uso más común sea una
línea. Esto es *aditivo* sobre B, no una alternativa.

```ruby
# Texto
result = Rasti::AI.generate_text model: 'anthropic:claude-sonnet-4-5',
                                 system: 'Act as sports journalist',
                                 prompt: 'who is the best player'

result.text            # => 'Lionel Messi'
result.usage           # => Usage
result.messages        # => historial canónico
result.steps           # => [Step] con tool calls/results por iteración
result.finish_reason   # => :stop

# Objeto estructurado
result = Rasti::AI.generate_object model: 'openai:gpt-4o',
                                  schema: PlayerForm,        # Rasti::Form → JSON Schema
                                  prompt: 'who is the best player'
result.object          # => {player: 'Lionel Messi', sport: 'Football'}

# Agente reutilizable con estado
agent = Rasti::AI::Agent.new model: 'gemini:gemini-2.0-flash',
                             instructions: 'Act as sports journalist',
                             tools: [GetCurrentWeather.new],
                             mcp_servers: {weather: mcp_client},
                             thinking: 'medium'

agent.call 'what is the weather in Buenos Aires'
agent.call 'and tomorrow?'      # mismo thread
agent.messages                  # canónico, serializable
```

Ideas adicionales que este diseño habilita naturalmente:

- **`schema:` acepta un `Rasti::Form`** en vez de un Hash a mano — cierra el círculo con
  `ToolSerializer`, que ya sabe convertir Forms a JSON Schema. El `json_schema:` actual (Hash
  crudo) sigue funcionando.
- **`Rasti::AI.model('openai:gpt-4o')`** como objeto de primera clase, reutilizable e inyectable:
  `Agent.new model: Rasti::AI.model('...', api_key: tenant.key)` → multi-tenant sin globals.
- **Middleware** (`wrapLanguageModel` de Vercel): un provider decorado para logging, caché de
  respuestas, usage tracking, redacción de PII, o fallback. `usage_tracker` pasa a ser un
  middleware más y deja de estar hardcodeado en el `Client`.
- **`max_steps:`** para acotar el loop de tools (hoy `loop do` no tiene tope: un modelo que
  insiste en llamar tools puede colgar el proceso indefinidamente — es un bug latente).
- **Nombres**: `Assistant` → `Agent`, `AssistantState` → `Thread`/`Session`. Alinea con el
  vocabulario de la industria y con lo que la clase realmente es.

---

## 5. Recomendación

Camino en dos releases, sin trabajo tirado:

1. **3.2.0 — Opción A.** Registry de providers + `Rasti::AI.assistant(provider:, model:)` +
   `Rasti::AI.generate` + `default_provider`. Compatible. Deja la elección de provider como dato
   y define la superficie pública que va a sobrevivir al refactor.
2. **4.0.0 — Opción B + C.** Mensajes canónicos y adaptadores por debajo; `generate_text` /
   `generate_object` / `Agent` por arriba. Las clases `<Provider>::Assistant` quedan como
   subclases de una línea, así que el código existente sigue compilando salvo quien inspeccione
   `state.messages`.

Dos puntos a decidir antes de arrancar:

- ¿Se mantiene `<Provider>::Client` como API pública (shim) o se deprecia? Afecta cuánto código
  legacy sobrevive en 4.0.
- ¿`Agent` reemplaza a `Assistant` o convive? Sugerencia: `Agent` como nombre nuevo y
  `Assistant = Agent` como alias, deprecando en 5.0.

Restricción a respetar en toda la implementación: **Ruby 2.3**. Sin pattern matching, sin
`transform_keys`, sin `Hash#slice`. Los objetos canónicos con `Rasti::Model` (que ya es
dependencia) resuelven la parte de tipado sin agregar nada.
