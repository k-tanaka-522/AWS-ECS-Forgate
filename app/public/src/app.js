/**
 * Public Web Service - Express Application
 *
 * 目的: HTTPリクエストハンドリング、ルーティング
 */

const express = require('express');
const { db } = require('@myapp/shared');

const app = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// リクエストロギング
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

/**
 * ヘルスチェックエンドポイント
 * ALBとECSのヘルスチェックで使用
 */
app.get('/health', async (req, res) => {
  try {
    // データベース接続確認
    const pool = db.getPool();
    await pool.query('SELECT 1');

    res.status(200).json({
      status: 'healthy',
      service: 'public-web',
      timestamp: new Date().toISOString(),
      database: 'connected'
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      service: 'public-web',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

/**
 * ルートエンドポイント
 */
app.get('/', (req, res) => {
  res.json({
    service: 'Public Web Application',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production',
    message: 'Welcome to the public web service'
  });
});

/**
 * ユーザー一覧取得エンドポイント（サンプル）
 */
app.get('/api/users', async (req, res) => {
  try {
    const result = await db.query('SELECT id, username, email, created_at FROM users ORDER BY created_at DESC LIMIT 10');

    res.json({
      success: true,
      count: result.rowCount,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * ユーザー登録エンドポイント（サンプル）
 */
app.post('/api/users', async (req, res) => {
  try {
    const { username, email } = req.body;

    // バリデーション
    if (!username || !email) {
      return res.status(400).json({
        success: false,
        error: 'Username and email are required'
      });
    }

    // ユーザー作成
    const result = await db.query(
      'INSERT INTO users (username, email) VALUES ($1, $2) RETURNING id, username, email, created_at',
      [username, email]
    );

    res.status(201).json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating user:', error);

    // 重複エラー
    if (error.code === '23505') {
      return res.status(409).json({
        success: false,
        error: 'User already exists'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * 統計情報エンドポイント（サンプル）
 */
app.get('/api/stats', async (req, res) => {
  try {
    const userCount = await db.query('SELECT COUNT(*) FROM users');
    const orderCount = await db.query('SELECT COUNT(*) FROM orders');

    res.json({
      success: true,
      data: {
        totalUsers: parseInt(userCount.rows[0].count, 10),
        totalOrders: parseInt(orderCount.rows[0].count, 10),
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * 404 Not Found
 */
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not Found'
  });
});

/**
 * エラーハンドリングミドルウェア
 */
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

module.exports = app;
