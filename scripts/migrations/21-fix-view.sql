-- Fix the view to use correct column names
-- Drop the old view
DROP VIEW IF EXISTS public.numeros_cada_participante;

-- Recreate the view with correct column references
CREATE OR REPLACE VIEW public.numeros_cada_participante AS
SELECT
  p.id,
  p.documento,
  p.nome,
  p.email,
  p.telefone,
  p.rua,
  p.numero,
  p.complemento,
  p.cidade,
  p.cep,
  p.uf,
  p.senha,
  p.quantidade_numeros,
  ARRAY_AGG(ns.numero) AS numeros_sorte
FROM
  participantes p
LEFT JOIN
  numeros_sorte ns ON p.documento = ns.documento
GROUP BY
  p.id,
  p.documento,
  p.nome,
  p.email,
  p.telefone,
  p.rua,
  p.numero,
  p.complemento,
  p.cidade,
  p.cep,
  p.uf,
  p.senha,
  p.quantidade_numeros;

-- Grant permissions on the view
GRANT SELECT ON public.numeros_cada_participante TO anon, authenticated;