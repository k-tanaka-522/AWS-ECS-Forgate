/**
 * Database Configuration
 *
 * Provides database connection with Secrets Manager integration
 */

import knex, { Knex } from 'knex';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

interface DbConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

async function getDbCredentials(): Promise<DbConfig> {
  const secretArn = process.env.DB_SECRET_ARN;

  if (!secretArn) {
    // Development mode - use environment variables directly
    return {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      database: process.env.DB_NAME || 'sampledb',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'password',
    };
  }

  // Production mode - fetch from Secrets Manager
  const client = new SecretsManagerClient({
    region: process.env.AWS_REGION || 'ap-northeast-1',
  });

  const command = new GetSecretValueCommand({ SecretId: secretArn });
  const response = await client.send(command);

  if (!response.SecretString) {
    throw new Error('Secret value not found');
  }

  const secret = JSON.parse(response.SecretString);

  return {
    host: secret.host || process.env.DB_HOST || 'localhost',
    port: parseInt(secret.port || process.env.DB_PORT || '5432', 10),
    database: secret.database || process.env.DB_NAME || 'sampledb',
    user: secret.username || process.env.DB_USER || 'postgres',
    password: secret.password,
  };
}

let cachedDb: Knex | null = null;

export async function getDbConnection(): Promise<Knex> {
  if (cachedDb) {
    return cachedDb;
  }

  const config = await getDbCredentials();

  cachedDb = knex({
    client: 'pg',
    connection: config,
    pool: {
      min: 2,
      max: 10,
    },
  });

  return cachedDb;
}

export async function closeDbConnection(): Promise<void> {
  if (cachedDb) {
    await cachedDb.destroy();
    cachedDb = null;
  }
}
