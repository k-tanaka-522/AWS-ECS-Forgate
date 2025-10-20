/**
 * Public Web Service - Entry Point
 *
 * 目的: 一般ユーザー向けWebアプリケーション
 * 構成: Express.js + PostgreSQL
 * デプロイ: ECS Fargate (Public ALB経由)
 */

const app = require('./app');
const { db } = require('@myapp/shared');

const PORT = process.env.PORT || 8080;
const SERVICE_NAME = process.env.SERVICE_NAME || 'public-web';
const NODE_ENV = process.env.NODE_ENV || 'production';

/**
 * サーバー起動
 */
async function startServer() {
  try {
    // データベース接続確認
    console.log(`[${SERVICE_NAME}] Connecting to database...`);
    await db.getConnection();
    console.log(`[${SERVICE_NAME}] Database connection established`);

    // Express サーバー起動
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`[${SERVICE_NAME}] Server started successfully`);
      console.log(`[${SERVICE_NAME}] Environment: ${NODE_ENV}`);
      console.log(`[${SERVICE_NAME}] Listening on port ${PORT}`);
    });
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Failed to start server:`, error);
    process.exit(1);
  }
}

/**
 * グレースフルシャットダウン
 */
async function gracefulShutdown(signal) {
  console.log(`[${SERVICE_NAME}] ${signal} received, shutting down gracefully...`);

  try {
    // データベース接続クローズ
    await db.closeConnection();
    console.log(`[${SERVICE_NAME}] Database connections closed`);

    process.exit(0);
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error during shutdown:`, error);
    process.exit(1);
  }
}

// シグナルハンドリング
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// 未処理エラーハンドリング
process.on('unhandledRejection', (reason, promise) => {
  console.error(`[${SERVICE_NAME}] Unhandled Rejection at:`, promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error(`[${SERVICE_NAME}] Uncaught Exception:`, error);
  process.exit(1);
});

// サーバー起動
startServer();
