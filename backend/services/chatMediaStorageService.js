import { Buffer } from 'node:buffer';
import { randomUUID } from 'node:crypto';

import sharp from 'sharp';

const DEFAULT_CHAT_MEDIA_BUCKET = 'chat-media';
const DEFAULT_SIGNED_URL_SECONDS = 60 * 60;
const DEFAULT_MAX_IMAGE_INPUT_BYTES = 6 * 1024 * 1024;
const DEFAULT_MAX_IMAGE_BYTES = 1024 * 1024;
const DEFAULT_MAX_VOICE_BYTES = 3 * 1024 * 1024;
const DEFAULT_MAX_VOICE_SECONDS = 60;
const MAX_IMAGE_SIDE = 1600;

const imageInputMimeTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

const voiceMimeExtensions = {
  'audio/aac': 'aac',
  'audio/mp4': 'm4a',
  'audio/mpeg': 'mp3',
  'audio/ogg': 'ogg',
  'audio/webm': 'webm',
  'audio/wav': 'wav',
};

export class ChatMediaStorageError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = 'ChatMediaStorageError';
    this.status = status;
  }
}

function readPositiveIntEnv(name, fallback) {
  const configured = Number.parseInt(process.env[name], 10);
  return Number.isInteger(configured) && configured > 0
    ? configured
    : fallback;
}

export function chatMediaBucket() {
  return process.env.SUPABASE_CHAT_MEDIA_BUCKET || DEFAULT_CHAT_MEDIA_BUCKET;
}

function signedUrlSeconds() {
  return readPositiveIntEnv(
    'SUPABASE_CHAT_MEDIA_SIGNED_URL_SECONDS',
    DEFAULT_SIGNED_URL_SECONDS,
  );
}

function maxImageInputBytes() {
  return readPositiveIntEnv(
    'SUPABASE_CHAT_IMAGE_MAX_INPUT_BYTES',
    DEFAULT_MAX_IMAGE_INPUT_BYTES,
  );
}

function maxImageBytes() {
  return readPositiveIntEnv(
    'SUPABASE_CHAT_IMAGE_MAX_BYTES',
    DEFAULT_MAX_IMAGE_BYTES,
  );
}

function maxVoiceBytes() {
  return readPositiveIntEnv(
    'SUPABASE_CHAT_VOICE_MAX_BYTES',
    DEFAULT_MAX_VOICE_BYTES,
  );
}

export function maxVoiceSeconds() {
  return readPositiveIntEnv('CHAT_VOICE_MAX_SECONDS', DEFAULT_MAX_VOICE_SECONDS);
}

function getStorageConfig() {
  const projectRef = (process.env.SUPABASE_PROJECT_REF || '').trim();
  const supabaseUrl = projectRef
    ? `https://${projectRef}.supabase.co`
    : (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const serviceRoleKey =
    process.env.SUPABASE_SECRET_KEY ||
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SERVICE_KEY ||
    '';
  const apiKey =
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    serviceRoleKey;

  if (!supabaseUrl || !serviceRoleKey || !apiKey) {
    throw new ChatMediaStorageError(
      'Storage de chat no configurado en el servidor',
      503,
    );
  }

  return { supabaseUrl, serviceRoleKey, apiKey };
}

function encodeStoragePath(path) {
  return path.split('/').map(encodeURIComponent).join('/');
}

function storageObjectUrl(supabaseUrl, objectPath) {
  return `${supabaseUrl}/storage/v1/object/${encodeURIComponent(
    chatMediaBucket(),
  )}/${encodeStoragePath(objectPath)}`;
}

function storageObjectSignUrl(supabaseUrl, objectPath) {
  return `${supabaseUrl}/storage/v1/object/sign/${encodeURIComponent(
    chatMediaBucket(),
  )}/${encodeStoragePath(objectPath)}`;
}

function normalizeMimeType(mimeType) {
  const normalized = String(mimeType || '').toLowerCase().trim();
  if (normalized === 'image/jpg') {
    return 'image/jpeg';
  }
  if (
    normalized === 'audio/m4a' ||
    normalized === 'audio/x-m4a' ||
    normalized === 'audio/x-mp4'
  ) {
    return 'audio/mp4';
  }
  if (normalized === 'audio/x-wav') {
    return 'audio/wav';
  }
  return normalized;
}

function parseAttachmentDataUrl(dataUrl) {
  const match = /^data:([^;,]+);base64,(.+)$/s.exec(String(dataUrl || '').trim());
  if (!match) {
    throw new ChatMediaStorageError('Archivo no valido');
  }

  const mimeType = normalizeMimeType(match[1]);
  const base64Payload = match[2].replace(/\s/g, '');
  if (!base64Payload || !/^[A-Za-z0-9+/]+={0,2}$/.test(base64Payload)) {
    throw new ChatMediaStorageError('Archivo no valido');
  }

  const buffer = Buffer.from(base64Payload, 'base64');
  if (buffer.length === 0) {
    throw new ChatMediaStorageError('Archivo no valido');
  }

  return { buffer, mimeType };
}

async function processImage(buffer, mimeType) {
  if (!imageInputMimeTypes.has(mimeType)) {
    throw new ChatMediaStorageError('Tipo de imagen no permitido');
  }

  if (buffer.length > maxImageInputBytes()) {
    throw new ChatMediaStorageError('La imagen pesa demasiado');
  }

  try {
    let output = await sharp(buffer, { limitInputPixels: 40_000_000 })
      .rotate()
      .resize({
        width: MAX_IMAGE_SIDE,
        height: MAX_IMAGE_SIDE,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 76, effort: 4 })
      .toBuffer({ resolveWithObject: true });

    if (output.data.length > maxImageBytes()) {
      output = await sharp(buffer, { limitInputPixels: 40_000_000 })
        .rotate()
        .resize({
          width: 1400,
          height: 1400,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 64, effort: 4 })
        .toBuffer({ resolveWithObject: true });
    }

    if (output.data.length > maxImageBytes()) {
      throw new ChatMediaStorageError('La imagen sigue pesando demasiado');
    }

    return {
      buffer: output.data,
      mimeType: 'image/webp',
      extension: 'webp',
      sizeBytes: output.data.length,
      width: output.info.width || null,
      height: output.info.height || null,
      durationSeconds: null,
    };
  } catch (error) {
    if (error instanceof ChatMediaStorageError) {
      throw error;
    }
    throw new ChatMediaStorageError('No se pudo procesar la imagen');
  }
}

function processVoice(buffer, mimeType, durationSeconds) {
  const extension = voiceMimeExtensions[mimeType];
  if (!extension) {
    throw new ChatMediaStorageError('Tipo de audio no permitido');
  }

  const parsedDuration = Number.parseInt(durationSeconds, 10);
  if (
    !Number.isInteger(parsedDuration) ||
    parsedDuration < 1 ||
    parsedDuration > maxVoiceSeconds()
  ) {
    throw new ChatMediaStorageError(
      `La nota de voz debe durar entre 1 y ${maxVoiceSeconds()} segundos`,
    );
  }

  if (buffer.length > maxVoiceBytes()) {
    throw new ChatMediaStorageError('La nota de voz pesa demasiado');
  }

  return {
    buffer,
    mimeType,
    extension,
    sizeBytes: buffer.length,
    width: null,
    height: null,
    durationSeconds: parsedDuration,
  };
}

async function uploadChatMediaBuffer({ objectPath, buffer, mimeType }) {
  const { supabaseUrl, serviceRoleKey, apiKey } = getStorageConfig();

  const response = await fetch(storageObjectUrl(supabaseUrl, objectPath), {
    method: 'POST',
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': mimeType,
      'Cache-Control': '31536000',
    },
    body: buffer,
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    console.error('Error subiendo adjunto de chat a Supabase Storage:', {
      status: response.status,
      body,
    });
    throw new ChatMediaStorageError('No se pudo guardar el archivo', 502);
  }
}

export async function createSignedChatMediaUrl(objectPath) {
  if (!objectPath) {
    return null;
  }

  const { supabaseUrl, serviceRoleKey, apiKey } = getStorageConfig();
  const response = await fetch(storageObjectSignUrl(supabaseUrl, objectPath), {
    method: 'POST',
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ expiresIn: signedUrlSeconds() }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    console.warn('No se pudo firmar adjunto de chat:', {
      status: response.status,
      body,
    });
    return null;
  }

  const payload = await response.json().catch(() => ({}));
  const signedUrl =
    payload.signedURL || payload.signedUrl || payload.signed_url || '';

  if (!signedUrl) {
    return null;
  }

  if (/^https?:\/\//i.test(signedUrl)) {
    return signedUrl;
  }

  const normalizedPath = signedUrl.startsWith('/')
    ? signedUrl
    : `/${signedUrl}`;
  return `${supabaseUrl}/storage/v1${normalizedPath}`;
}

export async function addSignedUrlsToMessages(messages) {
  await Promise.all(
    (messages || []).map(async (message) => {
      if (!message?.attachment?.path) {
        return;
      }

      message.attachment.url = await createSignedChatMediaUrl(
        message.attachment.path,
      );
    }),
  );

  return messages;
}

export async function prepareChatMediaAttachment({
  userId,
  conversationId,
  messageType,
  attachmentDataUrl,
  attachmentDurationSeconds = null,
}) {
  const type = messageType === 'voice' ? 'voice' : 'image';
  const { buffer, mimeType } = parseAttachmentDataUrl(attachmentDataUrl);
  const processed =
    type === 'image'
      ? await processImage(buffer, mimeType)
      : processVoice(buffer, mimeType, attachmentDurationSeconds);

  const objectPath = [
    'conversations',
    conversationId,
    type,
    `${Date.now()}-${userId}-${randomUUID()}.${processed.extension}`,
  ].join('/');

  await uploadChatMediaBuffer({
    objectPath,
    buffer: processed.buffer,
    mimeType: processed.mimeType,
  });

  return {
    kind: type,
    bucket: chatMediaBucket(),
    objectPath,
    mimeType: processed.mimeType,
    sizeBytes: processed.sizeBytes,
    width: processed.width,
    height: processed.height,
    durationSeconds: processed.durationSeconds,
  };
}

export async function deleteChatMediaObject(objectPath) {
  if (!objectPath) {
    return false;
  }

  const { supabaseUrl, serviceRoleKey, apiKey } = getStorageConfig();
  const response = await fetch(
    `${supabaseUrl}/storage/v1/object/${encodeURIComponent(chatMediaBucket())}`,
    {
      method: 'DELETE',
      headers: {
        apikey: apiKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ prefixes: [objectPath] }),
    },
  );

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    console.warn('No se pudo borrar adjunto de chat:', {
      status: response.status,
      body,
    });
    return false;
  }

  return true;
}

export async function deleteChatMediaObjects(objectPaths) {
  const paths = [...new Set((objectPaths || []).filter(Boolean))];
  await Promise.all(paths.map((objectPath) => deleteChatMediaObject(objectPath)));
}
