// Brainwager Phase 2 — Edge Function verify-purchase (squelette Deno)
// Valide le purchase token Google Play puis upsert public.entitlements.
// À déployer en Phase 5 (Billing). Ici : contrat + restauration prévus.
// Étapes manquantes (à faire Phase 5, à vérifier dans la doc Play Developer API) :
// 1. Créer un compte de service Google + clé JSON, partager l'accès Play Console.
// 2. Renseigner GOOGLE_SERVICE_ACCOUNT_JSON, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//    dans les secrets de la function (supabase secrets set).
// 3. Appeler POST /verify-purchase {sku, purchaseToken, mode: 'verify'|'restore'}.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('method-not-allowed', { status: 405 });
  }
  const body = await req.json().catch(() => null);
  const sku: string | undefined = body?.sku;
  const purchaseToken: string | undefined = body?.purchaseToken;
  const mode: string = body?.mode ?? 'verify';
  if (!sku || !purchaseToken) {
    return new Response(JSON.stringify({ error: 'missing-sku-or-token' }), {
      status: 400,
      headers: { 'content-type': 'application/json' },
    });
  }
  // TODO Phase 5 : valider purchaseToken via
  // androidpublisher.purchases.products.get / subscriptions.get.
  // Pour la Phase 2, on refuse proprement (pas d'écriture client possible).
  return new Response(
    JSON.stringify({ ok: false, mode, sku, error: 'not-configured-phase5' }),
    { status: 501, headers: { 'content-type': 'application/json' } },
  );
});
