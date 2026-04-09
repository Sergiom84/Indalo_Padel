import pkg from 'pg';
import './loadEnv.js';

const { Pool } = pkg;

const rawConnStr = process.env.DATABASE_URL;
const explicitDemoMode =
  process.env.DEMO_MODE === 'true' ||
  process.env.VITE_DEMO_MODE === 'true';
export const isDemoMode =
  explicitDemoMode ||
  (!rawConnStr && process.env.NODE_ENV !== 'production');
export const hasDatabaseConnection = Boolean(rawConnStr) && !explicitDemoMode;

if (!rawConnStr && !isDemoMode) {
  throw new Error(
    '❌ DATABASE_URL no está definida. Configura la variable de entorno DATABASE_URL en tu archivo .env'
  );
}

function createDemoPool() {
  const unavailable = async () => {
    throw new Error('Modo demo activo: el backend no tiene una base de datos conectada');
  };

  return {
    on() {},
    query: unavailable,
    connect: unavailable,
    end: async () => {},
  };
}

if (!rawConnStr && isDemoMode) {
  console.warn('⚠️ Modo demo activo: backend sin base de datos. Se omite la conexión PostgreSQL.');
}

if (rawConnStr && explicitDemoMode) {
  console.warn('⚠️ DEMO_MODE activo: se ignora DATABASE_URL y el backend funcionará sin PostgreSQL.');
}

let poolInstance;

if (!rawConnStr || explicitDemoMode) {
  poolInstance = createDemoPool();
} else {
  let parsed;
  try {
    parsed = new URL(rawConnStr);
  } catch (e) {
    console.error('❌ DATABASE_URL inválida:', e.message);
    throw e;
  }

  const host = parsed.hostname;
  const port = Number(parsed.port || 5432);
  const database = decodeURIComponent(parsed.pathname.replace(/^\//, '')) || 'postgres';
  let user = decodeURIComponent(parsed.username || 'postgres');
  const password = decodeURIComponent(parsed.password || '');

  const isSupabasePooler = host?.includes('.pooler.supabase.com');
  const hasTenantSuffix = user?.includes('.');
  if (isSupabasePooler && !hasTenantSuffix) {
    const supabaseUrl = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
    let projectRef = process.env.SUPABASE_PROJECT_REF;

    if (!projectRef && supabaseUrl) {
      try {
        const supabaseHost = new URL(supabaseUrl).hostname;
        projectRef = supabaseHost.split('.')[0];
      } catch (err) {
        console.warn('⚠️ SUPABASE_URL inválida:', err.message);
      }
    }

    if (projectRef) {
      console.warn(`⚠️ Pooler Supabase detectado. Ajustando usuario a postgres.${projectRef}`);
      user = `${user}.${projectRef}`;
    }
  }

  console.log(`🔌 DB target → host=${host} port=${port} db=${database} user=${user}`);

  const DB_SEARCH_PATH = process.env.DB_SEARCH_PATH || 'app,public';

  poolInstance = new Pool({
    host,
    port,
    database,
    user,
    password,
    ssl: { rejectUnauthorized: false },
    application_name: 'IndaloPadel',
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 15000,
    keepAlive: true,
    keepAliveInitialDelayMillis: 10000,
    options: `--search_path=${DB_SEARCH_PATH}`,
  });
}

export const pool = poolInstance;

export const testConnection = async () => {
  if (!hasDatabaseConnection) {
    console.log('ℹ️ Conexión a BD omitida porque el proyecto está en modo demo');
    return;
  }

  try {
    const client = await pool.connect();
    console.log('✅ Conexión a PostgreSQL exitosa');
    const { rows } = await client.query(`
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'app' AND table_name = 'users'
      ) AS ok;
    `);
    if (rows?.[0]?.ok) {
      console.log('✅ Tabla users encontrada');
    } else {
      console.warn('⚠️ Tabla users no encontrada - ejecuta las migraciones');
    }
    client.release();
  } catch (error) {
    console.error('❌ Error conectando a PostgreSQL:', error.message);
  }
};

testConnection();

export default pool;
