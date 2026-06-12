# SkinLog — Contrato de API

**Base URL:** `https://<host>/api/v1`  
**Protocolo:** HTTPS  
**Formato:** JSON (exceto upload de imagem, que usa `multipart/form-data`)  
**Autenticação:** Bearer Token (JWT emitido pelo Supabase via `/auth/login` ou `/auth/signup`)

---

## Índice

1. [Autenticação e Autorização](#1-autenticação-e-autorização)
2. [Erros Comuns](#2-erros-comuns)
3. [Rotas de Auth](#3-rotas-de-auth)
   - [POST /auth/signup](#31-post-authsignup)
   - [POST /auth/login](#32-post-authlogin)
   - [POST /auth/refresh](#33-post-authrefresh)
   - [POST /auth/logout](#34-post-authlogout)
   - [GET /auth/me](#35-get-authme)
4. [Rotas de Records](#4-rotas-de-records)
   - [POST /records](#41-post-records)
   - [GET /records](#42-get-records)
   - [GET /records/{id}](#43-get-recordsid)
   - [DELETE /records/{id}](#44-delete-recordsid)
   - [GET /records/streak](#45-get-recordsstreak)
   - [GET /records/latest](#46-get-recordslatest)
   - [POST /records/compare](#47-post-recordscompare)
5. [Schemas de Referência](#5-schemas-de-referência)
6. [Health Check](#6-health-check)

---

## 1. Autenticação e Autorização

Todas as rotas, exceto `/health`, `/auth/signup`, `/auth/login` e `/auth/refresh`, exigem o header:

```
Authorization: Bearer <access_token>
```

O `access_token` é um JWT HS256 emitido pelo Supabase. Ele expira em **1 hora**. Use `/auth/refresh` para obter um novo token sem exigir que o usuário faça login novamente.

**Fluxo recomendado no app:**

1. Ao iniciar, verificar se há `access_token` e `refresh_token` armazenados localmente.
2. Antes de qualquer requisição autenticada, checar se o `access_token` ainda é válido (por exemplo, decodificando o claim `exp` localmente).
3. Se expirado, chamar `POST /auth/refresh` automaticamente.
4. Se o refresh também falhar (token inválido/revogado), redirecionar para a tela de login.

---

## 2. Erros Comuns

O backend retorna erros no formato padrão do FastAPI:

```json
{
  "detail": "Mensagem de erro descritiva."
}
```

| HTTP Status | Significado |
|---|---|
| `400 Bad Request` | Dados de entrada inválidos (formato, campo obrigatório ausente, tipo de arquivo não suportado) |
| `401 Unauthorized` | Token ausente, inválido ou expirado |
| `403 Forbidden` | Token válido, mas o usuário não tem permissão para acessar o recurso |
| `404 Not Found` | Recurso não encontrado ou não pertence ao usuário autenticado |
| `422 Unprocessable Entity` | Falha de validação do body (Pydantic) — o campo `detail` conterá uma lista detalhada dos erros |
| `500 Internal Server Error` | Erro inesperado no servidor |

---

## 3. Rotas de Auth

### 3.1 `POST /auth/signup`

Cria uma nova conta de usuário e retorna tokens de sessão.

**Autenticação:** Nenhuma.

**Request Body** (`application/json`):

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `name` | `string` | ✅ | Nome de exibição do usuário |
| `email` | `string` | ✅ | Endereço de e-mail válido |
| `password` | `string` | ✅ | Senha (mínimo definido pelo Supabase Auth — recomendado 8+ caracteres) |

**Exemplo de request:**

```json
{
  "name": "Maria Silva",
  "email": "maria@exemplo.com",
  "password": "senhasegura123"
}
```

**Response `201 Created`** (`TokenOut`):

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "v1.MgV8...",
  "token_type": "bearer",
  "user": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "email": "maria@exemplo.com",
    "name": "Maria Silva",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

**Erros esperados:**

| Status | Cenário |
|---|---|
| `400` | E-mail já cadastrado, e-mail inválido, ou senha muito fraca |
| `422` | Campos obrigatórios ausentes ou com tipo errado |

---

### 3.2 `POST /auth/login`

Autentica um usuário existente e retorna tokens de sessão.

**Autenticação:** Nenhuma.

**Request Body** (`application/json`):

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `email` | `string` | ✅ | E-mail cadastrado |
| `password` | `string` | ✅ | Senha do usuário |

**Exemplo de request:**

```json
{
  "email": "maria@exemplo.com",
  "password": "senhasegura123"
}
```

**Response `200 OK`** (`TokenOut`):

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "v1.MgV8...",
  "token_type": "bearer",
  "user": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "email": "maria@exemplo.com",
    "name": "Maria Silva",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

**Erros esperados:**

| Status | Cenário |
|---|---|
| `400` | Credenciais inválidas (e-mail não encontrado ou senha incorreta) |
| `422` | Campos obrigatórios ausentes |

---

### 3.3 `POST /auth/refresh`

Troca um `refresh_token` válido por um novo par de tokens. Use quando o `access_token` expirar.

**Autenticação:** Nenhuma (o próprio `refresh_token` serve como credencial).

**Request Body** (`application/json`):

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `refresh_token` | `string` | ✅ | Refresh token obtido no signup ou login |

**Exemplo de request:**

```json
{
  "refresh_token": "v1.MgV8..."
}
```

**Response `200 OK`** (`TokenOut`):

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "v1.XyZ9...",
  "token_type": "bearer",
  "user": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "email": "maria@exemplo.com",
    "name": "Maria Silva",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

> ⚠️ O `refresh_token` retornado é um **novo** token. Substitua o que estava armazenado localmente por este novo valor.

**Erros esperados:**

| Status | Cenário |
|---|---|
| `400` | Refresh token inválido, expirado ou já utilizado |
| `422` | Campo `refresh_token` ausente |

---

### 3.4 `POST /auth/logout`

Invalida a sessão atual no Supabase. Após o logout, o `access_token` e o `refresh_token` atuais não poderão mais ser usados.

**Autenticação:** ✅ Obrigatória (`Authorization: Bearer <access_token>`).

**Request Body:** Nenhum.

**Response:** `204 No Content` (sem body).

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token ausente ou inválido |

---

### 3.5 `GET /auth/me`

Retorna os dados do perfil do usuário autenticado.

**Autenticação:** ✅ Obrigatória.

**Request Body:** Nenhum.

**Response `200 OK`** (`MeOut`):

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "email": "maria@exemplo.com",
  "name": "Maria Silva",
  "created_at": "2025-01-15T10:30:00Z"
}
```

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token ausente ou inválido |
| `404` | Perfil não encontrado (situação anômala — usuário existe no Auth mas não na tabela `profiles`) |

---

## 4. Rotas de Records

Um **record** representa um registro diário da pele do usuário, contendo a foto enviada, a análise gerada pela IA e observações opcionais.

> **Importante:** O upload da foto e a análise de IA acontecem em uma única chamada (`POST /records`). A análise é processada em **background** após a criação do record. Isso significa que um record recém-criado pode ser retornado com `ai_score: null` e `ai_analysis: null` imediatamente após o POST — o app deve lidar com esse estado de carregamento.

---

### 4.1 `POST /records`

Cria um novo registro de pele. Faz upload da foto, dispara a análise de IA em background e persiste o record.

**Autenticação:** ✅ Obrigatória.

**Request Body:** `multipart/form-data`

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `photo` | `file` | ✅ | Imagem da pele. Formatos aceitos: `image/jpeg`, `image/png`, `image/webp` |
| `notes` | `string` | ❌ | Observações livres do usuário (ex: "Pele mais oleosa hoje") |

**Exemplo de request (curl):**

```bash
curl -X POST https://<host>/api/v1/records \
  -H "Authorization: Bearer <access_token>" \
  -F "photo=@foto_pele.jpg;type=image/jpeg" \
  -F "notes=Acordei com a pele mais seca"
```

**Response `201 Created`** (`RecordOut`):

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "photo_url": "skin-photos/a1b2c3d4.../f47ac10b....jpg",
  "photo_signed_url": "https://storage.supabase.co/...?token=...&expires=3600",
  "ai_score": null,
  "ai_analysis": null,
  "notes": "Acordei com a pele mais seca",
  "created_at": "2025-06-06T08:00:00Z"
}
```

> `ai_score` e `ai_analysis` são `null` imediatamente após a criação. Faça um `GET /records/{id}` alguns segundos depois para obter os dados preenchidos.

**Comportamento em caso de erro:**
- Se o upload da foto ocorrer mas a persistência no banco falhar, o backend automaticamente remove o arquivo do Storage (cleanup).

**Erros esperados:**

| Status | Cenário |
|---|---|
| `400` | Formato de arquivo não suportado |
| `401` | Token inválido ou ausente |
| `422` | Campo `photo` ausente |

---

### 4.2 `GET /records`

Lista os registros do usuário autenticado, ordenados do mais recente para o mais antigo. Suporta paginação por cursor.

**Autenticação:** ✅ Obrigatória.

**Query Parameters:**

| Parâmetro | Tipo | Padrão | Descrição |
|---|---|---|---|
| `limit` | `integer` | `20` | Número de registros por página. Mínimo: 1, Máximo: 100 |
| `cursor` | `string` | `null` | Timestamp ISO 8601 do último item da página anterior (valor de `next_cursor` da resposta anterior) |

**Exemplo de request:**

```
GET /api/v1/records?limit=20
GET /api/v1/records?limit=20&cursor=2025-06-05T08:00:00Z
```

**Response `200 OK`** (`PaginatedRecordsOut`):

```json
{
  "data": [
    {
      "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
      "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "photo_url": "skin-photos/a1b2c3d4.../f47ac10b....jpg",
      "photo_signed_url": "https://storage.supabase.co/...?token=...&expires=3600",
      "ai_score": 7.5,
      "ai_analysis": {
        "score": 7.5,
        "redness": "Leve vermelhidão nas bochechas",
        "acne": "Nenhuma lesão ativa",
        "dryness": "Pele levemente ressecada na testa",
        "oiliness": "Oleosidade moderada na zona T",
        "observations": "Pele geral em bom estado, com pequenas variações de textura.",
        "recommendations": "Considere usar um hidratante leve após a limpeza matinal."
      },
      "notes": "Acordei com a pele mais seca",
      "created_at": "2025-06-06T08:00:00Z"
    }
  ],
  "next_cursor": "2025-06-05T08:00:00Z",
  "has_more": true
}
```

**Paginação:**
- Se `has_more` for `true`, passe o valor de `next_cursor` como query parameter `cursor` na próxima requisição para obter a próxima página.
- Se `has_more` for `false` ou `next_cursor` for `null`, não há mais registros.

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token inválido ou ausente |
| `422` | Valores de query param inválidos (ex: `limit` fora do range) |

---

### 4.3 `GET /records/{id}`

Retorna o detalhe de um registro específico. Apenas registros do usuário autenticado são acessíveis.

**Autenticação:** ✅ Obrigatória.

**Path Parameters:**

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `UUID` | ID do registro |

**Exemplo de request:**

```
GET /api/v1/records/f47ac10b-58cc-4372-a567-0e02b2c3d479
```

**Response `200 OK`** (`RecordOut`):

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "photo_url": "skin-photos/a1b2c3d4.../f47ac10b....jpg",
  "photo_signed_url": "https://storage.supabase.co/...?token=...&expires=3600",
  "ai_score": 7.5,
  "ai_analysis": {
    "score": 7.5,
    "redness": "Leve vermelhidão nas bochechas",
    "acne": "Nenhuma lesão ativa",
    "dryness": "Pele levemente ressecada na testa",
    "oiliness": "Oleosidade moderada na zona T",
    "observations": "Pele geral em bom estado, com pequenas variações de textura.",
    "recommendations": "Considere usar um hidratante leve após a limpeza matinal."
  },
  "notes": "Acordei com a pele mais seca",
  "created_at": "2025-06-06T08:00:00Z"
}
```

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token inválido ou ausente |
| `404` | Registro não encontrado ou não pertence ao usuário |

---

### 4.4 `DELETE /records/{id}`

Remove um registro e a foto associada do Storage. A operação é irreversível.

**Autenticação:** ✅ Obrigatória.

**Path Parameters:**

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `UUID` | ID do registro a ser removido |

**Exemplo de request:**

```
DELETE /api/v1/records/f47ac10b-58cc-4372-a567-0e02b2c3d479
```

**Response:** `204 No Content` (sem body).

> A remoção do arquivo do Storage é feita com best-effort. Mesmo que a deleção da foto falhe, o registro no banco é removido com sucesso.

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token inválido ou ausente |
| `404` | Registro não encontrado ou não pertence ao usuário |

---

### 4.5 `GET /records/streak`

Retorna a sequência atual de dias consecutivos com ao menos um registro.

**Autenticação:** ✅ Obrigatória.

**Request Body:** Nenhum.

**Response `200 OK`** (`StreakOut`):

```json
{
  "streak_days": 5,
  "last_record_date": "2025-06-06"
}
```

**Campos da resposta:**

| Campo | Tipo | Descrição |
|---|---|---|
| `streak_days` | `integer` | Número de dias consecutivos com registro (começa em 0 se não houver nenhum) |
| `last_record_date` | `string` (date) | Data do registro mais recente no formato `YYYY-MM-DD`. `null` se não houver registros |

**Lógica do streak:**
- Conta dias distintos com registro a partir de hoje (ou ontem, caso não haja registro hoje).
- Um dia sem registro quebra a sequência.

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token inválido ou ausente |

---

### 4.6 `GET /records/latest`

Atalho que retorna o registro mais recente do usuário. Equivale a `GET /records?limit=1`, mas mais direto.

**Autenticação:** ✅ Obrigatória.

**Request Body:** Nenhum.

**Response `200 OK`** (`RecordOut`):

```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "photo_url": "skin-photos/a1b2c3d4.../f47ac10b....jpg",
  "photo_signed_url": "https://storage.supabase.co/...?token=...&expires=3600",
  "ai_score": 7.5,
  "ai_analysis": { "..." : "..." },
  "notes": null,
  "created_at": "2025-06-06T08:00:00Z"
}
```

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token inválido ou ausente |
| `404` | Usuário não possui nenhum registro |

---

### 4.7 `POST /records/compare`

Compara dois registros do usuário, retornando ambos com suas análises e a diferença de score entre eles.

**Autenticação:** ✅ Obrigatória.

**Request Body** (`application/json`):

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `record_id_a` | `UUID` | ✅ | ID do primeiro registro (geralmente o mais recente) |
| `record_id_b` | `UUID` | ✅ | ID do segundo registro (geralmente o mais antigo) |

**Exemplo de request:**

```json
{
  "record_id_a": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "record_id_b": "b1c2d3e4-f5a6-7890-bcde-f01234567890"
}
```

**Response `200 OK`** (`RecordCompareOut`):

```json
{
  "record_a": {
    "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "ai_score": 7.5,
    "ai_analysis": { "..." : "..." },
    "photo_signed_url": "https://...",
    "created_at": "2025-06-06T08:00:00Z",
    "..."  : "..."
  },
  "record_b": {
    "id": "b1c2d3e4-f5a6-7890-bcde-f01234567890",
    "ai_score": 6.0,
    "ai_analysis": { "..." : "..." },
    "photo_signed_url": "https://...",
    "created_at": "2025-05-27T08:00:00Z",
    "..." : "..."
  },
  "score_diff": 1.5,
  "days_between": 10
}
```

**Campos da resposta:**

| Campo | Tipo | Descrição |
|---|---|---|
| `record_a` | `RecordOut` | Dados completos do primeiro registro |
| `record_b` | `RecordOut` | Dados completos do segundo registro |
| `score_diff` | `float \| null` | `record_a.ai_score - record_b.ai_score`. Positivo indica melhora de A em relação a B. `null` se algum dos registros ainda não tiver score |
| `days_between` | `integer` | Diferença absoluta em dias entre as datas dos dois registros |

**Erros esperados:**

| Status | Cenário |
|---|---|
| `401` | Token inválido ou ausente |
| `404` | Um ou ambos os registros não foram encontrados ou não pertencem ao usuário |
| `422` | `record_id_a` ou `record_id_b` ausentes ou não são UUIDs válidos |

---

## 5. Schemas de Referência

### `TokenOut`

Retornado por `/auth/signup`, `/auth/login` e `/auth/refresh`.

```json
{
  "access_token": "string (JWT)",
  "refresh_token": "string",
  "token_type": "bearer",
  "user": "UserOut"
}
```

---

### `UserOut` / `MeOut`

Retornado dentro de `TokenOut` e diretamente por `/auth/me`.

```json
{
  "id": "UUID",
  "email": "string",
  "name": "string",
  "created_at": "datetime (ISO 8601)"
}
```

---

### `AIAnalysis`

Presente em `RecordOut.ai_analysis`. Pode ser `null` enquanto a análise ainda está sendo processada.

```json
{
  "score": 7.5,
  "redness": "string — descrição do nível de vermelhidão",
  "acne": "string — descrição da presença e intensidade de acne",
  "dryness": "string — descrição do ressecamento",
  "oiliness": "string — descrição da oleosidade",
  "observations": "string — observações gerais da IA sobre a pele",
  "recommendations": "string — recomendações de cuidado"
}
```

| Campo | Tipo | Range | Descrição |
|---|---|---|---|
| `score` | `float` | 0.0 – 10.0 | Pontuação geral da saúde da pele |
| `redness` | `string` | — | Análise de vermelhidão |
| `acne` | `string` | — | Análise de acne/lesões |
| `dryness` | `string` | — | Análise de ressecamento |
| `oiliness` | `string` | — | Análise de oleosidade |
| `observations` | `string` | — | Observações gerais |
| `recommendations` | `string` | — | Recomendações de skincare |

---

### `RecordOut`

Schema principal de um registro. Retornado pela maioria das rotas de `/records`.

```json
{
  "id": "UUID",
  "user_id": "UUID",
  "photo_url": "string — path interno no bucket do Storage",
  "photo_signed_url": "string — URL temporária (válida por 1 hora) para exibir a imagem",
  "ai_score": "float | null",
  "ai_analysis": "AIAnalysis | null",
  "notes": "string | null",
  "created_at": "datetime (ISO 8601)"
}
```

> `photo_signed_url` expira em **1 hora**. Para exibir imagens após esse período, faça um novo `GET /records/{id}` ou `GET /records` para obter URLs atualizadas.

---

### `PaginatedRecordsOut`

Retornado por `GET /records`.

```json
{
  "data": "RecordOut[]",
  "next_cursor": "string (datetime ISO 8601) | null",
  "has_more": "boolean"
}
```

---

### `StreakOut`

Retornado por `GET /records/streak`.

```json
{
  "streak_days": "integer",
  "last_record_date": "string (YYYY-MM-DD) | null"
}
```

---

### `RecordCompareOut`

Retornado por `POST /records/compare`.

```json
{
  "record_a": "RecordOut",
  "record_b": "RecordOut",
  "score_diff": "float | null",
  "days_between": "integer"
}
```

---

## 6. Health Check

### `GET /health`

Verifica se o serviço está no ar. Não requer autenticação. Útil para monitoramento e para o app checar conectividade com o backend antes de operações críticas.

**Response `200 OK`:**

```json
{
  "status": "ok"
}
```

---

## Observações Finais

**Armazenamento local recomendado:** Persista `access_token`, `refresh_token` e os dados básicos do usuário (`id`, `name`, `email`) em armazenamento seguro (ex: Flutter Secure Storage). Não armazene a `service_role_key` do Supabase — ela nunca é exposta ao app.

**Imagens:** Use sempre `photo_signed_url` para exibição. O campo `photo_url` é o path interno no bucket e não é acessível diretamente. As signed URLs têm validade de 1 hora.

**Análise de IA assíncrona:** Após `POST /records`, o record é criado imediatamente mas a análise roda em background. Implemente polling no `GET /records/{id}` (ex: a cada 3–5 segundos por até 30 segundos) ou exiba um estado de carregamento na UI enquanto `ai_score` for `null`.

**Documentação interativa:** Com o backend rodando localmente, acesse `http://localhost:8000/docs` para o Swagger UI gerado automaticamente pelo FastAPI, onde é possível testar todas as rotas diretamente pelo browser.
