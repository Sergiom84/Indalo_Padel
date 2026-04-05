import dotenv from 'dotenv';
import { existsSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const envCandidates = [
  path.resolve(__dirname, '../.env'),
  path.resolve(__dirname, '.env'),
];

export function loadEnvironment() {
  if (process.env.NODE_ENV === 'production') {
    return null;
  }

  const envPath = envCandidates.find((candidate) => existsSync(candidate));
  if (envPath) {
    dotenv.config({ path: envPath });
    return envPath;
  }

  dotenv.config();
  return null;
}

loadEnvironment();
