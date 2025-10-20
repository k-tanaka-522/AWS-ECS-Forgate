/**
 * Admin Dashboard Service - Express Application
 *
 * 目的: 管理者向けAPI・ダッシュボード
 * セキュリティ: VPN/Direct Connect経由のみアクセス可能
 */

const express = require('express');
const { db } = require('@myapp/shared');

const app = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// リクエストロギング
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path} from ${req.ip}`);
  next();
});

/**
 * ヘルスチェックエンドポイント
 */
app.get('/health', async (req, res) => {
  try {
    const pool = db.getPool();
    await pool.query('SELECT 1');

    res.status(200).json({
      status: 'healthy',
      service: 'admin-dashboard',
      timestamp: new Date().toISOString(),
      database: 'connected'
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      service: 'admin-dashboard',
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
    service: 'Admin Dashboard',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production',
    message: 'Admin dashboard service (VPN access only)',
    access: 'restricted'
  });
});

/**
 * システム統計情報取得（管理者用）
 */
app.get('/api/admin/stats', async (req, res) => {
  try {
    // 各種統計情報を取得
    const userStats = await db.query(`
      SELECT
        COUNT(*) as total_users,
        COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') as new_users_24h,
        COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as new_users_7d
      FROM users
    `);

    const orderStats = await db.query(`
      SELECT
        COUNT(*) as total_orders,
        COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') as orders_24h,
        SUM(total_amount) as total_revenue,
        SUM(total_amount) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') as revenue_24h
      FROM orders
    `);

    res.json({
      success: true,
      data: {
        users: userStats.rows[0],
        orders: orderStats.rows[0],
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error fetching admin stats:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * 全ユーザー一覧取得（管理者用）
 */
app.get('/api/admin/users', async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 50;
    const offset = (page - 1) * limit;

    const result = await db.query(
      'SELECT id, username, email, created_at, updated_at FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2',
      [limit, offset]
    );

    const countResult = await db.query('SELECT COUNT(*) FROM users');
    const totalCount = parseInt(countResult.rows[0].count, 10);

    res.json({
      success: true,
      page,
      limit,
      totalCount,
      totalPages: Math.ceil(totalCount / limit),
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
 * ユーザー削除（管理者用）
 */
app.delete('/api/admin/users/:id', async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID'
      });
    }

    const result = await db.query('DELETE FROM users WHERE id = $1 RETURNING id', [userId]);

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    res.json({
      success: true,
      message: 'User deleted successfully',
      userId
    });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

/**
 * システム情報取得（管理者用）
 */
app.get('/api/admin/system', async (req, res) => {
  try {
    // データベース接続情報
    const dbVersion = await db.query('SELECT version()');
    const dbSize = await db.query(`
      SELECT pg_size_pretty(pg_database_size(current_database())) as size
    `);

    // アプリケーション情報
    const appInfo = {
      service: 'admin-dashboard',
      version: '1.0.0',
      environment: process.env.NODE_ENV || 'production',
      nodeVersion: process.version,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage()
    };

    res.json({
      success: true,
      data: {
        application: appInfo,
        database: {
          version: dbVersion.rows[0].version,
          size: dbSize.rows[0].size
        },
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error fetching system info:', error);
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
