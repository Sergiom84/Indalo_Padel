import { Buffer } from 'node:buffer';

const DEFAULT_AVATAR_BUCKET = 'avatars';
const DEFAULT_MAX_AVATAR_BYTES = 512 * 1024;

const allowedMimeTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

const mimeExtensions = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

export class AvatarStorageError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = 'AvatarStorageError';
    this.status = status;
  }
}

function avatarBucket() {
  return process.env.SUPABASE_AVATAR_BUCKET || DEFAULT_AVATAR_BUCKET;
}

function maxAvatarBytes() {
  const configured = Number.parseInt(process.env.SUPABASE_AVATAR_MAX_BYTES, 10);
  return Number.isInteger(configured) && configured > 0
    ? configured
    : DEFAULT_MAX_AVATAR_BYTES;
}

function getStorageConfig() {
  const projectRef = (process.env.SUPABASE_PROJECT_REF || '').trim();
  const supabaseUrl = projectRef
    ? `https://${projectRef}.supabase.co`
    : (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const serviceRoleKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

  if (!supabaseUrl || !serviceRoleKey) {
    throw new AvatarStorageError(
      'Storage de avatares no configurado en el servidor',
      503,
    );
  }

  return { supabaseUrl, serviceRoleKey };
}

function encodeStoragePath(path) {
  return path.split('/').map(encodeURIComponent).join('/');
}

function storageObjectUrl(supabaseUrl, objectPath) {
  return `${supabaseUrl}/storage/v1/object/${encodeURIComponent(
    avatarBucket(),
  )}/${encodeStoragePath(objectPath)}`;
}

function storagePublicUrl(supabaseUrl, objectPath) {
  return `${supabaseUrl}/storage/v1/object/public/${encodeURIComponent(
    avatarBucket(),
  )}/${encodeStoragePath(objectPath)}`;
}

function normalizeMimeType(mimeType) {
  const normalized = String(mimeType || '').toLowerCase().trim();
  return normalized === 'image/jpg' ? 'image/jpeg' : normalized;
}

function parseAvatarDataUrl(dataUrl) {
  const match = /^data:([^;,]+);base64,(.+)$/s.exec(String(dataUrl || '').trim());
  if (!match) {
    throw new AvatarStorageError('Formato de foto no valido');
  }

  const mimeType = normalizeMimeType(match[1]);
  if (!allowedMimeTypes.has(mimeType)) {
    throw new AvatarStorageError('Tipo de foto no permitido');
  }

  const base64Payload = match[2].replace(/\s/g, '');
  if (!base64Payload || !/^[A-Za-z0-9+/]+={0,2}$/.test(base64Payload)) {
    throw new AvatarStorageError('Foto no valida');
  }

  const buffer = Buffer.from(base64Payload, 'base64');
  if (buffer.length === 0) {
    throw new AvatarStorageError('Foto no valida');
  }

  if (buffer.length > maxAvatarBytes()) {
    throw new AvatarStorageError(
      'La foto sigue pesando demasiado. Elige otra imagen o recortala.',
    );
  }

  return { buffer, mimeType };
}

export function isAvatarDataUrl(value) {
  return typeof value === 'string' && value.trim().startsWith('data:');
}

export function avatarPathFromPublicUrl(rawUrl) {
  const value = String(rawUrl || '').trim();
  if (!value) {
    return null;
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }

  const projectRef = (process.env.SUPABASE_PROJECT_REF || '').trim();
  const configuredUrl = projectRef
    ? `https://${projectRef}.supabase.co`
    : (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  if (!configuredUrl) {
    return null;
  }

  let configuredHost;
  try {
    configuredHost = new URL(configuredUrl).host;
  } catch {
    return null;
  }
  const prefix = `/storage/v1/object/public/${avatarBucket()}/`;
  if (parsed.host !== configuredHost || !parsed.pathname.startsWith(prefix)) {
    return null;
  }

  return parsed.pathname
    .slice(prefix.length)
    .split('/')
    .map((segment) => decodeURIComponent(segment))
    .join('/');
}

export async function uploadAvatarDataUrl({ userId, dataUrl }) {
  const { supabaseUrl, serviceRoleKey } = getStorageConfig();
  const { buffer, mimeType } = parseAvatarDataUrl(dataUrl);
  const extension = mimeExtensions[mimeType];
  const objectPath = `users/${userId}/avatar-${Date.now()}.${extension}`;

  const response = await fetch(storageObjectUrl(supabaseUrl, objectPath), {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': mimeType,
      'Cache-Control': '31536000',
    },
    body: buffer,
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    console.error('Error subiendo avatar a Supabase Storage:', {
      status: response.status,
      body,
    });
    throw new AvatarStorageError('No se pudo guardar la foto de perfil', 502);
  }

  return storagePublicUrl(supabaseUrl, objectPath);
}

export async function deleteAvatarByPublicUrl(publicUrl) {
  const objectPath = avatarPathFromPublicUrl(publicUrl);
  if (!objectPath) {
    return false;
  }

  const { supabaseUrl, serviceRoleKey } = getStorageConfig();
  const response = await fetch(
    `${supabaseUrl}/storage/v1/object/${encodeURIComponent(avatarBucket())}`,
    {
      method: 'DELETE',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ prefixes: [objectPath] }),
    },
  );

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    console.warn('No se pudo borrar avatar antiguo de Storage:', {
      status: response.status,
      body,
    });
    return false;
  }

  return true;
}
