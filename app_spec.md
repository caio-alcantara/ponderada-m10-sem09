# 🧴 SkinLog — Spec Document

## 1. Visão Geral

### 1.1 Problema
Pessoas em tratamentos dermatológicos (como Roacutan/Isotretinoína) têm dificuldade em acompanhar visualmente a evolução da pele ao longo do tempo. Fotos ficam perdidas na galeria, não há registro estruturado e é difícil comparar o progresso de forma objetiva.

### 1.2 Solução
**SkinLog** é um aplicativo mobile que permite ao usuário registrar fotos diárias do rosto, receber análises automatizadas por IA sobre a condição da pele e comparar a evolução ao longo do tratamento. O app funciona como um diário visual inteligente da pele.

### 1.3 Público-alvo
- Pessoas em tratamento dermatológico (Roacutan, ácidos, etc.)
- Pessoas que desejam acompanhar a saúde da pele
- Pacientes que querem compartilhar evolução com dermatologistas

### 1.4 Diferencial
- Análise automatizada por IA (Gemini Vision) a cada foto
- Comparador antes/depois com seleção de duas fotos
- Score numérico de evolução da pele
- Dados sensíveis protegidos com bucket privado e RLS

---

## 2. Stack Tecnológica

| Camada | Tecnologia |
|--------|-----------|
| Mobile | Flutter (Dart) |
| Backend / Auth | Supabase (Auth com email + senha) |
| Banco de Dados | PostgreSQL (Supabase) |
| Storage | Supabase Storage (bucket privado) |
| API Externa (IA) | Google Gemini 1.5 Flash (Vision / Multimodal) |
| Notificações | flutter_local_notifications (local) |
| Compartilhamento | share_plus (nativo do SO) |
| Câmera | image_picker / camera |
| Navegação | go_router |

---

## 3. Telas e Funcionalidades

### 3.1 Tela 1 — Login / Cadastro

**Rota:** `/login`

**Descrição:**
Tela de autenticação do usuário utilizando Supabase Auth com email e senha.

**Funcionalidades:**
- Formulário de login (email + senha)
- Formulário de cadastro (email + senha + nome)
- Validação de campos (email válido, senha mínima 6 caracteres)
- Feedback de erro (credenciais inválidas, email já cadastrado)
- Persistência de sessão (manter logado)
- Redirecionamento automático para Home se já autenticado

**Campos do cadastro:**
| Campo | Tipo | Obrigatório |
|-------|------|-------------|
| Nome | String | Sim |
| Email | String (email) | Sim |
| Senha | String (min 6) | Sim |

**Estados da tela:**
- Idle (formulário vazio)
- Loading (aguardando resposta do Supabase)
- Error (exibir mensagem de erro)
- Success (redirecionar para Home)

---

### 3.2 Tela 2 — Home / Dashboard

**Rota:** `/home`

**Descrição:**
Tela principal do app. Exibe um resumo do progresso do tratamento, a última foto registrada, o streak de dias consecutivos e acesso rápido às demais funcionalidades.

**Funcionalidades:**
- Exibir última foto registrada com data e score IA
- Exibir streak de dias consecutivos com registro
- Botão principal "Registrar Hoje" → navega para Câmera
- Botão de acesso à galeria de análises
- Indicador visual se o registro do dia já foi feito
- Saudação com nome do usuário
- Logout

**Componentes visuais:**
- Card da última foto (thumbnail + data + score)
- Contador de streak (🔥 ex: "12 dias seguidos")
- Botão CTA grande "📸 Registrar Hoje"
- Botão secundário "📊 Ver Análises"
- Badge de "✅ Registro feito hoje" ou "⚠️ Pendente"

**Dados consumidos:**
- Último registro do usuário (tabela `records`)
- Contagem de streak (registros consecutivos por data)

---

### 3.3 Tela 3 — Câmera

**Rota:** `/camera`

**Descrição:**
Tela de captura de foto do rosto. Utiliza a câmera frontal do dispositivo com um guia oval para posicionamento consistente do rosto.

**Funcionalidades:**
- Abrir câmera frontal automaticamente
- Exibir guia oval translúcido para posicionamento do rosto
- Botão de captura
- Preview da foto tirada com opções: "Usar foto" ou "Tirar outra"
- Ao confirmar:
  1. Upload da imagem para Supabase Storage (bucket privado)
  2. Envio dos bytes da imagem para Gemini Vision
  3. Salvar análise no banco de dados
  4. Redirecionar para tela de Análise de Imagens

**Hardware utilizado:** Câmera frontal do dispositivo

**Fluxo técnico:**
```
Câmera frontal → Captura foto → Preview
  → Confirma → Upload Supabase Storage
  → Envia bytes para Gemini Vision API
  → Recebe análise JSON
  → Salva record no PostgreSQL
  → Redireciona para Análise
```

**Guia oval:**
- Overlay semi-transparente com recorte oval no centro
- Texto: "Posicione seu rosto dentro do guia"
- Garante consistência entre fotos para comparação

---

### 3.4 Tela 4 — Análise de Imagens

**Rota:** `/analysis`

**Descrição:**
Tela com galeria de todas as fotos do usuário, cada uma com sua análise de IA. Permite visualizar detalhes de cada análise e selecionar duas fotos para comparação antes/depois.

**Funcionalidades:**

#### Modo Galeria (padrão)
- Grid de fotos em ordem cronológica (mais recente primeiro)
- Cada card exibe: thumbnail, data, score IA (ex: 7.2/10)
- Tap em uma foto → abre modal/bottom sheet com análise completa
- Análise completa inclui: score, vermelhidão, acne, ressecamento, oleosidade, observações

#### Modo Comparação
- Botão "Comparar" ativa modo de seleção
- Usuário seleciona exatamente 2 fotos (checkbox visual)
- Ao selecionar 2, abre tela de comparação:
  - Duas fotos lado a lado
  - Scores e datas de cada uma
  - Diferença de score (ex: "+1.5 de melhora")
  - Botão de compartilhar a comparação

#### Compartilhamento
- Gera imagem combinada (antes/depois com datas e scores)
- Usa `share_plus` para compartilhar via sheet nativo do SO
- Útil para enviar ao dermatologista via WhatsApp/email

**Componentes visuais:**
- Grid responsivo (2 ou 3 colunas)
- Card de foto com badge de score
- Modal de análise detalhada
- Tela de comparação com layout lado a lado
- Botão flutuante "Comparar"
- Botão de compartilhar

---

## 4. Modelagem do Banco de Dados

### 4.1 Diagrama de Tabelas

```
┌──────────────────────────┐
│         profiles         │
├──────────────────────────┤
│ id          UUID (PK/FK) │  ← auth.users.id
│ name        TEXT NOT NULL │
│ created_at  TIMESTAMPTZ  │
│ updated_at  TIMESTAMPTZ  │
└──────────┬───────────────┘
           │ 1:N
           ▼
┌──────────────────────────────────┐
│            records               │
├──────────────────────────────────┤
│ id             UUID (PK)         │
│ user_id        UUID (FK)         │  → profiles.id
│ photo_url      TEXT NOT NULL      │  (path no Storage)
│ ai_score       DECIMAL(3,1)      │  (1.0 a 10.0)
│ ai_analysis    JSONB             │  (análise completa)
│ notes          TEXT               │  (observações do usuário)
│ created_at     TIMESTAMPTZ       │
└──────────────────────────────────┘
```

### 4.2 DDL — SQL de Criação

```sql
-- Tabela de perfis (extensão do auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de registros de pele
CREATE TABLE records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  ai_score DECIMAL(3,1) CHECK (ai_score >= 0 AND ai_score <= 10),
  ai_analysis JSONB DEFAULT '{}',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_records_user_id ON records(user_id);
CREATE INDEX idx_records_created_at ON records(created_at DESC);
CREATE INDEX idx_records_user_date ON records(user_id, created_at DESC);
```

### 4.3 Row Level Security (RLS)

```sql
-- Habilitar RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE records ENABLE ROW LEVEL SECURITY;

-- Profiles: usuário só acessa o próprio perfil
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Records: usuário só acessa seus próprios registros
CREATE POLICY "Users can view own records"
  ON records FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own records"
  ON records FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own records"
  ON records FOR DELETE
  USING (auth.uid() = user_id);
```

### 4.4 Storage Policies

```sql
-- Bucket: skin-photos (privado)
-- Estrutura: skin-photos/{user_id}/{filename}

CREATE POLICY "Users can upload own photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'skin-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'skin-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'skin-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

### 4.5 Estrutura do campo `ai_analysis` (JSONB)

```json
{
  "score": 7.2,
  "redness": "leve",
  "acne": "moderada — algumas lesões ativas na zona T",
  "dryness": "ressecamento visível nos cantos da boca",
  "oiliness": "baixa",
  "observations": "Pele apresenta melhora em relação ao padrão de acne inflamatória. Ressecamento compatível com uso de isotretinoína.",
  "recommendations": "Manter hidratação labial. Protetor solar indispensável."
}
```

---

## 5. APIs Externas

### 5.1 Google Gemini 1.5 Flash (Vision)

**Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent`

**Autenticação:** API Key (via header ou query param)

**Free Tier:**
- 15 requests por minuto
- 1.500 requests por dia
- Suficiente para uso acadêmico

**Prompt padrão para análise:**

```
Você é um assistente dermatológico. Analise esta foto de pele facial e retorne APENAS um JSON válido (sem markdown, sem código) com a seguinte estrutura:

{
  "score": <número de 1.0 a 10.0, onde 10 é pele completamente saudável>,
  "redness": "<nenhuma | leve | moderada | intensa>",
  "acne": "<descrição breve da presença de acne>",
  "dryness": "<descrição breve do ressecamento>",
  "oiliness": "<nenhuma | baixa | moderada | alta>",
  "observations": "<observação geral sobre a condição da pele>",
  "recommendations": "<1-2 recomendações breves de cuidado>"
}

Seja objetivo e clínico. Não faça diagnósticos médicos.
```

**Integração no Flutter:**
```dart
// Usando package google_generative_ai
final model = GenerativeModel(
  model: 'gemini-1.5-flash',
  apiKey: apiKey,
);

final content = Content.multi([
  TextPart(prompt),
  DataPart('image/jpeg', imageBytes),
]);

final response = await model.generateContent([content]);
```

---

## 6. Notificações Locais

### 6.1 Implementação

**Package:** `flutter_local_notifications`

**Notificações agendadas:**

| Notificação | Horário | Mensagem |
|-------------|---------|----------|
| Lembrete matinal | 08:00 | "☀️ Bom dia! Não esqueça do protetor solar hoje." |
| Lembrete noturno | 21:00 | "📸 Hora de registrar sua pele! Mantenha o streak." |

### 6.2 Permissões
- Android: `POST_NOTIFICATIONS` (Android 13+)
- iOS: Solicitar permissão no primeiro uso

### 6.3 Lógica
- Notificações agendadas como `repeatInterval: RepeatInterval.daily`
- Configuradas no primeiro login
- Podem ser desativadas (flag local com shared_preferences)

---

## 7. Compartilhamento

### 7.1 Implementação

**Package:** `share_plus`

**Fluxo:**
1. Usuário seleciona 2 fotos no modo comparação
2. App gera imagem combinada (antes/depois) usando `Canvas` ou `screenshot` package
3. Imagem salva temporariamente no dispositivo
4. `Share.shareXFiles()` abre sheet nativo do SO
5. Usuário escolhe destino (WhatsApp, email, etc.)

**Conteúdo compartilhado:**
- Imagem: montagem antes/depois com datas e scores
- Texto: "Minha evolução de pele com SkinLog 🧴 — De {score1} para {score2} em {dias} dias!"

---

## 8. Segurança e Proteção de Dados

### 8.1 Medidas implementadas
- Bucket de fotos **privado** no Supabase Storage
- Acesso via **signed URLs** com expiração (1 hora)
- **RLS** em todas as tabelas e no Storage
- Estrutura de pastas por `user_id` no bucket
- Imagens enviadas ao Gemini como **bytes** (não como URL pública)
- Chaves de API em arquivo `.env` **não commitado** no repositório

### 8.2 .gitignore
```
# Chaves e configurações sensíveis
.env
*.env
lib/config/secrets.dart
```

### 8.3 Variáveis de ambiente
```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
GEMINI_API_KEY=AIzaSy...
```

**Package recomendado:** `flutter_dotenv` para carregar `.env` no app.

---

## 9. Estrutura de Pastas do Projeto

```
lib/
├── main.dart
├── config/
│   └── env.dart                  # Carregamento do .env
├── router/
│   └── app_router.dart           # Rotas com go_router
├── models/
│   ├── profile.dart
│   └── record.dart
├── services/
│   ├── auth_service.dart         # Supabase Auth
│   ├── storage_service.dart      # Supabase Storage
│   ├── database_service.dart     # Supabase PostgreSQL
│   └── gemini_service.dart       # Gemini Vision API
├── providers/                    # State management
│   ├── auth_provider.dart
│   └── records_provider.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── camera_screen.dart
│   └── analysis_screen.dart
├── widgets/
│   ├── face_guide_overlay.dart   # Guia oval da câmera
│   ├── record_card.dart          # Card de foto na galeria
│   ├── analysis_modal.dart       # Modal de análise detalhada
│   ├── comparison_view.dart      # View antes/depois
│   └── streak_counter.dart       # Widget de streak
└── utils/
    ├── image_utils.dart          # Manipulação de imagens
    ├── date_utils.dart           # Formatação de datas
    └── notification_utils.dart   # Config de notificações locais
```

---

## 10. Packages Flutter (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.0.0

  # Gemini AI
  google_generative_ai: ^0.4.0

  # Câmera
  image_picker: ^1.0.0

  # Navegação
  go_router: ^14.0.0

  # Notificações locais
  flutter_local_notifications: ^17.0.0

  # Compartilhamento
  share_plus: ^9.0.0

  # Variáveis de ambiente
  flutter_dotenv: ^5.1.0

  # Utilitários
  intl: ^0.19.0                   # Formatação de datas
  cached_network_image: ^3.3.0    # Cache de imagens
  shimmer: ^3.0.0                 # Loading skeleton
```

---

## 11. Checklist de Requisitos da Atividade

| # | Requisito | Como é atendido | Status |
|---|-----------|-----------------|--------|
| 1 | Aplicação mobile | Flutter (Android/iOS) | ✅ |
| 2 | Mais de 2 telas | 4 telas com navegação funcional | ✅ |
| 3 | Navegação funcional | go_router com rotas nomeadas | ✅ |
| 4 | Backend integrado | Supabase (Auth + DB + Storage) | ✅ |
| 5 | Banco de dados | PostgreSQL via Supabase | ✅ |
| 6 | API externa | Google Gemini 1.5 Flash (Vision) | ✅ |
| 7 | Compartilhamento | share_plus — antes/depois | ✅ |
| 8 | Notificações | flutter_local_notifications | ✅ |
| 9 | Hardware do celular | Câmera frontal | ✅ |
| 10 | Interface coerente | Design focado no propósito | ✅ |
| 11 | Tratamento de erros | Loading states, error handling | ✅ |
| 12 | Documentação | Este documento + README | ✅ |
| 13 | Código organizado | Estrutura de pastas definida | ✅ |

---

## 12. Considerações Finais

### 12.1 Disclaimer médico
O SkinLog **não substitui consulta médica**. As análises de IA são meramente informativas e não constituem diagnóstico. O app deve exibir esse aviso no onboarding e na tela de análise.

### 12.2 Evolução futura (fora do escopo atual)
- Tela de rotina de produtos (AM/PM)
- Tela de perfil com dados do tratamento
- Push notifications via Supabase Edge Functions
- Edge Function para proteger chave do Gemini
- Exportar relatório PDF para dermatologista
- Dark mode
- Suporte a múltiplas áreas do corpo (não só rosto)

### 12.3 Chaves de API
- Todas as chaves ficam em arquivo `.env` local
- O `.env` está no `.gitignore` e **nunca é commitado**
- O README deve conter instruções de como criar o `.env`