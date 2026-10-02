import { createClient } from 'npm:@supabase/supabase-js@2';

const PACKAGE_NAME = 'com.yakineeddine.brainwager';
const GOOGLE_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const GOOGLE_TOKEN_AUD = 'https://oauth2.googleapis.com/token';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type PurchaseMode = 'verify' | 'restore' | 'sync';

type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type GoogleProductPurchaseV2 = {
  productLineItem?: Array<{
    productId?: string;
    productOfferDetails?: {
      quantity?: number;
      refundableQuantity?: number;
      consumptionState?: string;
    };
  }>;
  purchaseStateContext?: {
    purchaseState?: string;
  };
  orderId?: string;
  obfuscatedExternalAccountId?: string;
  acknowledgementState?: string;
};

class BillingError extends Error {
  code: string;
  status: number;

  constructor(code: string, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

let cachedGoogleToken: { token: string; expiresAtMs: number } | null = null;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

function namedKey(jsonEnv: string, legacyEnv: string): string | null {
  const raw = Deno.env.get(jsonEnv);
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (typeof parsed?.default === 'string' && parsed.default.length > 0) {
        return parsed.default;
      }
    } catch {
      // Fall through to legacy key.
    }
  }
  const legacy = Deno.env.get(legacyEnv);
  return legacy && legacy.length > 0 ? legacy : null;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function stringToBase64Url(value: string): string {
  return bytesToBase64Url(new TextEncoder().encode(value));
}

function pemPkcs8ToBytes(pem: string): Uint8Array {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll(/\s+/g, '');
  const binary = atob(body);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function googleAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedGoogleToken && cachedGoogleToken.expiresAtMs > now + 60_000) {
    return cachedGoogleToken.token;
  }

  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new BillingError('billing-not-configured', 503);

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(raw) as ServiceAccount;
  } catch {
    throw new BillingError('billing-not-configured', 503);
  }

  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new BillingError('billing-not-configured', 503);
  }

  const nowSeconds = Math.floor(now / 1000);
  const header = stringToBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = stringToBase64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: GOOGLE_SCOPE,
    aud: serviceAccount.token_uri || GOOGLE_TOKEN_AUD,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemPkcs8ToBytes(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${bytesToBase64Url(new Uint8Array(signature))}`;

  const response = await fetch(serviceAccount.token_uri || GOOGLE_TOKEN_AUD, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new BillingError('google-auth-failed', 503);
  }

  const body = await response.json();
  const token = body?.access_token;
  const expiresIn = Number(body?.expires_in ?? 3600);
  if (typeof token !== 'string' || token.length === 0) {
    throw new BillingError('google-auth-failed', 503);
  }

  cachedGoogleToken = {
    token,
    expiresAtMs: now + Math.max(60, expiresIn - 60) * 1000,
  };
  return token;
}

async function getGooglePurchase(
  purchaseToken: string,
  accessToken: string,
): Promise<GoogleProductPurchaseV2> {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(PACKAGE_NAME)}/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });

  if (response.status === 404) {
    throw new BillingError('invalid-purchase-token', 400);
  }
  if (response.status === 401 || response.status === 403) {
    throw new BillingError('google-play-permission-denied', 503);
  }
  if (!response.ok) {
    throw new BillingError('google-verify-failed', 502);
  }

  return await response.json() as GoogleProductPurchaseV2;
}

async function acknowledgeGooglePurchase(
  sku: string,
  purchaseToken: string,
  accessToken: string,
): Promise<boolean> {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(PACKAGE_NAME)}/purchases/products/${encodeURIComponent(sku)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: '{}',
  });
  return response.ok;
}

function parsePurchase(
  purchase: GoogleProductPurchaseV2,
  requestedSku: string,
): {
  sku: string;
  purchaseState: 'PURCHASED' | 'PENDING' | 'CANCELLED';
  acknowledgementState: string;
  consumptionState: string;
  orderId: string | null;
  obfuscatedAccountId: string | null;
} {
  const line = purchase.productLineItem?.find(
    (item) => item.productId === requestedSku,
  );
  if (!line) throw new BillingError('purchase-sku-mismatch', 400);

  const quantity = Number(line.productOfferDetails?.quantity ?? 1);
  if (quantity !== 1) {
    throw new BillingError('unsupported-purchase-quantity', 400);
  }

  const refundableQuantity =
    Number(line.productOfferDetails?.refundableQuantity ?? quantity);

  const rawState = purchase.purchaseStateContext?.purchaseState;
  let purchaseState: 'PURCHASED' | 'PENDING' | 'CANCELLED';
  if (rawState === 'PURCHASED') {
    purchaseState = refundableQuantity <= 0 ? 'CANCELLED' : 'PURCHASED';
  } else if (rawState === 'PENDING') {
    purchaseState = 'PENDING';
  } else if (rawState === 'CANCELLED') {
    purchaseState = 'CANCELLED';
  } else {
    throw new BillingError('invalid-google-purchase-state', 502);
  }

  return {
    sku: requestedSku,
    purchaseState,
    acknowledgementState:
      purchase.acknowledgementState || 'ACKNOWLEDGEMENT_STATE_UNSPECIFIED',
    consumptionState:
      line.productOfferDetails?.consumptionState ||
      'CONSUMPTION_STATE_UNSPECIFIED',
    orderId:
      typeof purchase.orderId === 'string' && purchase.orderId.length > 0
        ? purchase.orderId
        : null,
    obfuscatedAccountId:
      typeof purchase.obfuscatedExternalAccountId === 'string' &&
          purchase.obfuscatedExternalAccountId.length > 0
        ? purchase.obfuscatedExternalAccountId
        : null,
  };
}

async function processPurchase(params: {
  admin: ReturnType<typeof createClient>;
  userId: string;
  sku: string;
  purchaseToken: string;
  mode: PurchaseMode;
  accessToken: string;
}): Promise<Record<string, unknown>> {
  const purchase = await getGooglePurchase(
    params.purchaseToken,
    params.accessToken,
  );
  const parsed = parsePurchase(purchase, params.sku);

  if (params.mode === 'verify') {
    const expectedAccount = await sha256Hex(params.userId);
    if (parsed.obfuscatedAccountId !== expectedAccount) {
      throw new BillingError('purchase-account-mismatch', 409);
    }
  }

  const { data, error } = await params.admin.rpc(
    'apply_google_play_purchase',
    {
      p_user: params.userId,
      p_purchase_token: params.purchaseToken,
      p_sku: params.sku,
      p_order_id: parsed.orderId,
      p_obfuscated_account_id: parsed.obfuscatedAccountId,
      p_purchase_state: parsed.purchaseState,
      p_acknowledgement_state: parsed.acknowledgementState,
      p_consumption_state: parsed.consumptionState,
      p_mode: params.mode,
    },
  );

  if (error) {
    const message = String(error.message ?? '');
    if (message.includes('purchase-token-already-claimed')) {
      throw new BillingError('purchase-token-already-claimed', 409);
    }
    if (message.includes('purchase-token-sku-mismatch')) {
      throw new BillingError('purchase-token-sku-mismatch', 409);
    }
    if (message.includes('billing-sku-not-allowed')) {
      throw new BillingError('billing-sku-not-allowed', 400);
    }
    throw new BillingError('billing-database-error', 500);
  }

  let acknowledged =
    parsed.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';

  if (
    parsed.purchaseState === 'PURCHASED' &&
    parsed.consumptionState !== 'CONSUMPTION_STATE_CONSUMED' &&
    !acknowledged
  ) {
    acknowledged = await acknowledgeGooglePurchase(
      params.sku,
      params.purchaseToken,
      params.accessToken,
    );
    if (acknowledged) {
      await params.admin
        .from('google_play_purchases')
        .update({
          acknowledgement_state: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
          updated_at: new Date().toISOString(),
        })
        .eq('purchase_token', params.purchaseToken);
    }
  }

  if (parsed.purchaseState === 'PENDING') {
    return {
      ok: false,
      error: 'purchase-pending',
      sku: params.sku,
      active: false,
      acknowledged,
    };
  }

  if (
    parsed.purchaseState !== 'PURCHASED' ||
    parsed.consumptionState === 'CONSUMPTION_STATE_CONSUMED'
  ) {
    return {
      ok: false,
      error: 'purchase-not-active',
      sku: params.sku,
      active: false,
      acknowledged,
    };
  }

  return {
    ok: true,
    sku: params.sku,
    active: true,
    acknowledged,
    transferred: Boolean(data?.transferred),
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ ok: false, error: 'method-not-allowed' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const publishableKey = namedKey(
      'SUPABASE_PUBLISHABLE_KEYS',
      'SUPABASE_ANON_KEY',
    );
    const secretKey = namedKey(
      'SUPABASE_SECRET_KEYS',
      'SUPABASE_SERVICE_ROLE_KEY',
    );

    if (!supabaseUrl || !publishableKey || !secretKey) {
      throw new BillingError('billing-backend-not-configured', 503);
    }

    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) {
      throw new BillingError('not-authenticated', 401);
    }

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      throw new BillingError('not-authenticated', 401);
    }

    const admin = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json().catch(() => null);
    const mode = body?.mode as PurchaseMode | undefined;

    if (!mode || !['verify', 'restore', 'sync'].includes(mode)) {
      throw new BillingError('invalid-purchase-mode', 400);
    }

    const accessToken = await googleAccessToken();

    if (mode === 'sync') {
      const { data: records, error: recordError } = await admin
        .from('google_play_purchases')
        .select('purchase_token,sku')
        .eq('user_id', user.id)
        .limit(100);

      if (recordError) {
        throw new BillingError('billing-database-error', 500);
      }

      let checked = 0;
      let failures = 0;
      for (const record of records ?? []) {
        try {
          await processPurchase({
            admin,
            userId: user.id,
            sku: record.sku,
            purchaseToken: record.purchase_token,
            mode: 'sync',
            accessToken,
          });
          checked++;
        } catch {
          // Never revoke on a transport/API failure. Only an explicit Google
          // state processed above can deactivate an entitlement.
          failures++;
        }
      }

      const { data: entitlements, error: entitlementError } = await admin
        .from('entitlements')
        .select('sku')
        .eq('user_id', user.id)
        .eq('is_active', true);

      if (entitlementError) {
        throw new BillingError('billing-database-error', 500);
      }

      return json({
        ok: true,
        mode: 'sync',
        checked,
        failures,
        activeSkus: (entitlements ?? []).map((row) => row.sku),
      });
    }

    const sku = typeof body?.sku === 'string' ? body.sku.trim() : '';
    const purchaseToken =
      typeof body?.purchaseToken === 'string' ? body.purchaseToken.trim() : '';

    if (!sku || !purchaseToken) {
      throw new BillingError('missing-sku-or-token', 400);
    }

    const result = await processPurchase({
      admin,
      userId: user.id,
      sku,
      purchaseToken,
      mode,
      accessToken,
    });

    return json({ ...result, mode });
  } catch (error) {
    if (error instanceof BillingError) {
      return json({ ok: false, error: error.code }, error.status);
    }
    return json({ ok: false, error: 'billing-internal-error' }, 500);
  }
});
