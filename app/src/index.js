require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const mysql = require('mysql2/promise');
const AWS = require('aws-sdk');

const app = express();
const port = process.env.PORT || 3000;

// AWS SDK configuration
const secretsManager = new AWS.SecretsManager({
  region: process.env.AWS_REGION || 'ap-northeast-1'
});

// Middleware
app.use(cors());
app.use(helmet());
app.use(express.json());

// Get database credentials based on environment
async function getDatabaseConfig() {
  if (process.env.NODE_ENV === 'development') {
    // ローカル開発環境: 環境変数から直接取得
    return {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    };
  } else {
    // 本番環境: AWS Secrets Managerから取得
    try {
      const data = await secretsManager.getSecretValue({
        SecretId: `${process.env.ENVIRONMENT}/escforgate/db-credentials`
      }).promise();
      
      return JSON.parse(data.SecretString);
    } catch (error) {
      console.error('Error retrieving database credentials:', error);
      throw error;
    }
  }
}

// Database connection configuration
async function createDbConnection() {
  try {
    const config = await getDatabaseConfig();
    return await mysql.createConnection(config);
  } catch (error) {
    console.error('Error creating database connection:', error);
    throw error;
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    environment: process.env.NODE_ENV
  });
});

// Test database connection
app.get('/db-test', async (req, res) => {
  try {
    console.log('Attempting database connection with config:', {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      database: process.env.DB_NAME
    });
    const connection = await createDbConnection();
    await connection.ping();
    await connection.end();
    res.status(200).json({ 
      status: 'database connection successful',
      host: process.env.NODE_ENV === 'development' ? process.env.DB_HOST : 'RDS'
    });
  } catch (error) {
    console.error('Database connection error:', error);
    res.status(500).json({ 
      error: 'database connection failed',
      message: error.message,
      code: error.code
    });
  }
});

// Test Cognito configuration
app.get('/auth-test', (req, res) => {
  const cognitoIdentityServiceProvider = new AWS.CognitoIdentityServiceProvider();
  const params = {
    UserPoolId: process.env.COGNITO_USER_POOL_ID,
  };

  cognitoIdentityServiceProvider.describeUserPool(params, (err, data) => {
    if (err) {
      console.error('Cognito error:', err);
      res.status(500).json({ error: 'cognito configuration failed' });
    } else {
      res.status(200).json({ status: 'cognito configuration successful' });
    }
  });
});

// Basic API endpoint
app.get('/api/status', (req, res) => {
  res.status(200).json({
    service: 'ESCForgate',
    version: '1.0.0',
    environment: process.env.NODE_ENV,
    database: process.env.NODE_ENV === 'development' ? 'local MySQL' : 'RDS'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log('Environment:', process.env.NODE_ENV);
  console.log('Database host:', process.env.DB_HOST);
});
