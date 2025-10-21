// Knex.js configuration file
// This file defines database connection settings for different environments

module.exports = {
  development: {
    client: 'pg',
    connection: {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      database: process.env.DB_NAME || 'sampledb',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'password',
    },
    pool: {
      min: 2,
      max: 10,
    },
    migrations: {
      directory: './migrations',
      tableName: 'knex_migrations',
    },
  },

  production: {
    client: 'pg',
    connection: async () => {
      // In production, fetch password from AWS Secrets Manager
      const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

      const secretArn = process.env.DB_SECRET_ARN;
      if (!secretArn) {
        throw new Error('DB_SECRET_ARN environment variable is required in production');
      }

      const client = new SecretsManagerClient({
        region: process.env.AWS_REGION || 'ap-northeast-1'
      });
      const command = new GetSecretValueCommand({ SecretId: secretArn });
      const response = await client.send(command);

      if (!response.SecretString) {
        throw new Error('Secret value not found');
      }

      const secret = JSON.parse(response.SecretString);

      return {
        host: secret.host || process.env.DB_HOST,
        port: parseInt(secret.port || process.env.DB_PORT || '5432', 10),
        database: secret.database || process.env.DB_NAME,
        user: secret.username || process.env.DB_USER,
        password: secret.password,
      };
    },
    pool: {
      min: 2,
      max: 10,
    },
    migrations: {
      directory: './migrations',
      tableName: 'knex_migrations',
    },
  },
};
