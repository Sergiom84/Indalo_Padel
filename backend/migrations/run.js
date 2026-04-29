import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import '../loadEnv.js';
import { pool } from '../db.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const migrationFiles = [
  path.join(__dirname, 'padel_tables.sql'),
  path.join(__dirname, 'padel_player_connections.sql'),
  path.join(__dirname, 'padel_community.sql'),
  path.join(__dirname, 'padel_player_profile_preferences.sql'),
  path.join(__dirname, 'padel_player_profile_personal_info.sql'),
  path.join(__dirname, 'padel_venue_dedup.sql'),
  path.join(__dirname, 'padel_calendar.sql'),
  path.join(__dirname, 'padel_seed_data.sql'),
  path.join(__dirname, 'padel_clubs_community_closure.sql'),
  path.join(__dirname, 'padel_auth_account_lifecycle.sql'),
  path.join(__dirname, 'padel_profile_deletion.sql'),
  path.join(__dirname, 'padel_match_results.sql'),
  path.join(__dirname, 'padel_community_product_updates.sql'),
  path.join(__dirname, 'padel_fcm_tokens.sql'),
  path.join(__dirname, 'padel_chat.sql'),
  path.join(__dirname, 'padel_social_events.sql'),
  path.join(__dirname, 'padel_avatar_storage.sql'),
  path.join(__dirname, 'padel_chat_media.sql'),
  path.join(__dirname, 'padel_supabase_auth_bridge.sql'),
];

async function run() {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    for (const filePath of migrationFiles) {
      const sql = await readFile(filePath, 'utf8');
      if (!sql.trim()) {
        continue;
      }

      console.log(`📄 Ejecutando migración: ${path.basename(filePath)}`);
      await client.query(sql);
    }

    await client.query('COMMIT');
    console.log('✅ Migraciones completadas correctamente');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error ejecutando migraciones:', error.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

run();
