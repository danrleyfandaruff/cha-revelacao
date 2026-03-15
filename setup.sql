-- ================================================================
-- CHÁ REVELAÇÃO — Setup Supabase
-- Execute este arquivo no SQL Editor do Supabase:
--   Dashboard → SQL Editor → New query → cole e Execute
-- ================================================================

-- ── 1. TABELA DE ITENS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS items (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  category           TEXT         NOT NULL CHECK (category IN ('fraldas', 'presentes')),
  name               TEXT         NOT NULL,
  description        TEXT,
  emoji              TEXT         DEFAULT '🎁',
  quantity_total     INT          NOT NULL DEFAULT 1 CHECK (quantity_total > 0),
  quantity_available INT          NOT NULL DEFAULT 1 CHECK (quantity_available >= 0),
  sort_order         INT          DEFAULT 0,
  created_at         TIMESTAMPTZ  DEFAULT NOW()
);

-- ── 2. TABELA DE RESERVAS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reservations (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id     UUID         NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  guest_name  TEXT         NOT NULL,
  created_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- ── 3. ROW LEVEL SECURITY ─────────────────────────────────────────
ALTER TABLE items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

-- Qualquer pessoa pode ler os itens
CREATE POLICY "items_public_read"
  ON items FOR SELECT USING (true);

-- Qualquer pessoa pode ler as reservas (para ver quem já reservou)
CREATE POLICY "reservations_public_read"
  ON reservations FOR SELECT USING (true);

-- ── 4. FUNÇÃO RPC: reserve_item ───────────────────────────────────
-- Operação atômica: verifica disponibilidade, decrementa e registra reserva
CREATE OR REPLACE FUNCTION reserve_item(p_item_id UUID, p_guest_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_available INT;
  v_name      TEXT;
BEGIN
  -- Busca e bloqueia a linha para evitar condição de corrida
  SELECT quantity_available, name
    INTO v_available, v_name
    FROM items
   WHERE id = p_item_id
     FOR UPDATE;

  IF v_available IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Item não encontrado.');
  END IF;

  IF v_available <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Que pena! Este item já foi reservado. Que tal escolher outro? 🌟'
    );
  END IF;

  -- Decrementa disponibilidade
  UPDATE items
     SET quantity_available = quantity_available - 1
   WHERE id = p_item_id;

  -- Registra a reserva
  INSERT INTO reservations (item_id, guest_name)
  VALUES (p_item_id, p_guest_name);

  RETURN json_build_object(
    'success', true,
    'message', 'Reservado com sucesso!'
  );
END;
$$;

-- ── 5. DADOS INICIAIS — FRALDAS ───────────────────────────────────
INSERT INTO items (category, name, description, emoji, quantity_total, quantity_available, sort_order)
VALUES
  ('fraldas', 'Fralda Recém-Nascido (RN)',        'Pacote de fraldas descartáveis tamanho RN, ideal para os primeiros dias',              '🧷', 5, 5,  1),
  ('fraldas', 'Fralda Tamanho P',                  'Pacote de fraldas descartáveis tamanho P',                                            '🧷', 5, 5,  2),
  ('fraldas', 'Fralda Tamanho M',                  'Pacote de fraldas descartáveis tamanho M',                                            '🧷', 5, 5,  3),
  ('fraldas', 'Fralda Tamanho G',                  'Pacote de fraldas descartáveis tamanho G',                                            '🧷', 3, 3,  4),
  ('fraldas', 'Lenços Umedecidos',                 'Pacote de lenços umedecidos para bebê, sem perfume e hipoalergênico',                  '🌿', 8, 8,  5),
  ('fraldas', 'Pomada para Assaduras',             'Pomada protetora para prevenir e tratar assaduras (ex: Desitin, Bepantol)',            '💛', 4, 4,  6),
  ('fraldas', 'Fralda de Pano (Kit 10 un.)',       'Kit com 10 fraldas de pano multiuso, suaves e laváveis',                              '🌼', 3, 3,  7),
  ('fraldas', 'Algodão Hidrófilo',                 'Rolo ou pacote de algodão hidrófilo para os cuidados diários com o bebê',             '☁️', 3, 3,  8),
  ('fraldas', 'Toalha Umedecida Reutilizável',     'Kit de toalhinhas de tecido reutilizáveis, ecológicas e extra macias',                '🌱', 2, 2,  9),
  ('fraldas', 'Trocador Portátil',                 'Trocador dobrável e impermeável, fácil de levar na bolsa de passeio',                 '👶', 2, 2, 10);

-- ── 6. DADOS INICIAIS — PRESENTES ────────────────────────────────
INSERT INTO items (category, name, description, emoji, quantity_total, quantity_available, sort_order)
VALUES
  ('presentes', 'Banheira de Bebê',                   'Banheirinha ergonômica com suporte antiderrapante para banho seguro',              '🛁', 1, 1,  1),
  ('presentes', 'Kit de Banho Completo',               'Toalha de capuz + esponja macia + sabonete + shampoo infantil',                   '🧴', 3, 3,  2),
  ('presentes', 'Body Manga Longa RN (Kit 3 un.)',     'Conjunto de 3 bodies manga longa tamanho recém-nascido em algodão',               '👶', 3, 3,  3),
  ('presentes', 'Body Manga Curta RN (Kit 3 un.)',     'Conjunto de 3 bodies manga curta tamanho recém-nascido em algodão',               '👶', 3, 3,  4),
  ('presentes', 'Macacão com Pé (Kit 2 un.)',          'Conjunto de 2 macacões quentinhos com pés, tamanho RN/P',                         '🌙', 3, 3,  5),
  ('presentes', 'Manta de Bebê',                       'Manta macia e quentinha para envolver o bebê com carinho',                        '🌸', 3, 3,  6),
  ('presentes', 'Chupeta Ortodôntica',                 'Chupeta com bico ortodôntico, sem BPA, para recém-nascido',                       '😊', 4, 4,  7),
  ('presentes', 'Mamadeira Anti-cólica',               'Mamadeira com bico de silicone e sistema anti-cólica',                            '🍼', 4, 4,  8),
  ('presentes', 'Kit Higiene Bebê',                    'Tesoura de ponta arredondada, lima de unhas, pente e escovinha',                   '💅', 2, 2,  9),
  ('presentes', 'Porta-Fraldas / Organizador',         'Organizador prático para fraldas e acessórios no berçário',                       '🧸', 2, 2, 10),
  ('presentes', 'Espreguiçadeira / Bouncer',           'Cadeirinha vibratória relaxante, perfeita para acalmar o bebê',                   '🌟', 1, 1, 11),
  ('presentes', 'Carregador / Sling Ergonômico',       'Carregador que mantém o bebê pertinho com segurança e conforto',                  '🤱', 1, 1, 12),
  ('presentes', 'Monitor de Bebê',                     'Babá eletrônica com vídeo e sensor de temperatura ambiente',                      '📱', 1, 1, 13),
  ('presentes', 'Bebê Conforto (Cadeirinha Auto)',      'Cadeirinha de carro grupo 0+ para bebês até 13 kg, homologada pelo Inmetro',      '🚗', 1, 1, 14),
  ('presentes', 'Carrinho de Bebê',                    'Carrinho reclinável, com cestão de compras e proteção UV',                        '🚼', 1, 1, 15);

-- ================================================================
-- ✅ Pronto! Acesse o Supabase Table Editor para ver os dados.
-- Para personalizar os itens, edite a tabela "items" direto no
-- Dashboard do Supabase (Table Editor) ou via SQL acima.
-- ================================================================
