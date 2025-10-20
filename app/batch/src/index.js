/**
 * Batch Processing Service - Entry Point
 *
 * 目的: データ処理・集計バッチ（定期実行）
 * 構成: Node.js + PostgreSQL
 * デプロイ: ECS Fargate (Scheduled Task or Long-running)
 */

const { db } = require('@myapp/shared');

const SERVICE_NAME = process.env.SERVICE_NAME || 'batch-processing';
const NODE_ENV = process.env.NODE_ENV || 'production';
const BATCH_INTERVAL = parseInt(process.env.BATCH_INTERVAL || '3600000', 10); // Default: 1 hour

/**
 * データ集計処理
 * 例: 日次統計情報の集計
 */
async function aggregateDailyStats() {
  const startTime = Date.now();
  console.log(`[${SERVICE_NAME}] Starting daily stats aggregation...`);

  try {
    // トランザクション開始
    const client = await db.getPool().connect();

    try {
      await client.query('BEGIN');

      // 本日の統計を集計
      const today = new Date().toISOString().split('T')[0];

      // ユーザー統計
      const userStats = await client.query(`
        INSERT INTO daily_stats (date, metric_name, metric_value)
        VALUES ($1, 'total_users', (SELECT COUNT(*) FROM users))
        ON CONFLICT (date, metric_name) DO UPDATE SET metric_value = EXCLUDED.metric_value
        RETURNING *
      `, [today]);

      // 注文統計
      const orderStats = await client.query(`
        INSERT INTO daily_stats (date, metric_name, metric_value)
        VALUES ($1, 'total_orders', (SELECT COUNT(*) FROM orders WHERE DATE(created_at) = $1))
        ON CONFLICT (date, metric_name) DO UPDATE SET metric_value = EXCLUDED.metric_value
        RETURNING *
      `, [today]);

      // 売上統計
      const revenueStats = await client.query(`
        INSERT INTO daily_stats (date, metric_name, metric_value)
        VALUES ($1, 'total_revenue', (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE DATE(created_at) = $1))
        ON CONFLICT (date, metric_name) DO UPDATE SET metric_value = EXCLUDED.metric_value
        RETURNING *
      `, [today]);

      await client.query('COMMIT');

      const duration = Date.now() - startTime;
      console.log(`[${SERVICE_NAME}] Daily stats aggregation completed in ${duration}ms`);
      console.log(`[${SERVICE_NAME}] Aggregated: ${userStats.rowCount} user stats, ${orderStats.rowCount} order stats, ${revenueStats.rowCount} revenue stats`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error during daily stats aggregation:`, error);
    throw error;
  }
}

/**
 * データクリーンアップ処理
 * 例: 古いログの削除
 */
async function cleanupOldData() {
  const startTime = Date.now();
  console.log(`[${SERVICE_NAME}] Starting old data cleanup...`);

  try {
    // 90日以上前のログを削除
    const result = await db.query(`
      DELETE FROM audit_logs
      WHERE created_at < NOW() - INTERVAL '90 days'
    `);

    const duration = Date.now() - startTime;
    console.log(`[${SERVICE_NAME}] Old data cleanup completed in ${duration}ms`);
    console.log(`[${SERVICE_NAME}] Deleted ${result.rowCount} old audit log records`);
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error during old data cleanup:`, error);
    throw error;
  }
}

/**
 * レポート生成処理
 * 例: 月次レポートの生成
 */
async function generateMonthlyReport() {
  const startTime = Date.now();
  console.log(`[${SERVICE_NAME}] Starting monthly report generation...`);

  try {
    const lastMonth = new Date();
    lastMonth.setMonth(lastMonth.getMonth() - 1);
    const yearMonth = `${lastMonth.getFullYear()}-${String(lastMonth.getMonth() + 1).padStart(2, '0')}`;

    // 月次統計を集計
    const result = await db.query(`
      INSERT INTO monthly_reports (year_month, total_users, total_orders, total_revenue, generated_at)
      SELECT
        $1,
        (SELECT COUNT(*) FROM users WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', $2::date)),
        (SELECT COUNT(*) FROM orders WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', $2::date)),
        (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', $2::date)),
        NOW()
      ON CONFLICT (year_month) DO UPDATE SET
        total_users = EXCLUDED.total_users,
        total_orders = EXCLUDED.total_orders,
        total_revenue = EXCLUDED.total_revenue,
        generated_at = EXCLUDED.generated_at
      RETURNING *
    `, [yearMonth, `${yearMonth}-01`]);

    const duration = Date.now() - startTime;
    console.log(`[${SERVICE_NAME}] Monthly report generation completed in ${duration}ms`);
    console.log(`[${SERVICE_NAME}] Report for ${yearMonth}:`, result.rows[0]);
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error during monthly report generation:`, error);
    throw error;
  }
}

/**
 * バッチ処理実行
 */
async function runBatch() {
  console.log(`[${SERVICE_NAME}] ========================================`);
  console.log(`[${SERVICE_NAME}] Batch execution started at ${new Date().toISOString()}`);

  try {
    // 各バッチ処理を実行
    await aggregateDailyStats();
    await cleanupOldData();

    // 月初のみ月次レポート生成
    const today = new Date().getDate();
    if (today === 1) {
      await generateMonthlyReport();
    }

    console.log(`[${SERVICE_NAME}] All batch processes completed successfully`);
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Batch execution failed:`, error);
  }

  console.log(`[${SERVICE_NAME}] ========================================`);
}

/**
 * メイン処理
 */
async function main() {
  console.log(`[${SERVICE_NAME}] Service started`);
  console.log(`[${SERVICE_NAME}] Environment: ${NODE_ENV}`);
  console.log(`[${SERVICE_NAME}] Batch interval: ${BATCH_INTERVAL}ms`);

  try {
    // データベース接続確認
    console.log(`[${SERVICE_NAME}] Connecting to database...`);
    await db.getConnection();
    console.log(`[${SERVICE_NAME}] Database connection established`);

    // 初回実行
    await runBatch();

    // 定期実行
    setInterval(async () => {
      try {
        await runBatch();
      } catch (error) {
        console.error(`[${SERVICE_NAME}] Scheduled batch execution failed:`, error);
      }
    }, BATCH_INTERVAL);

    console.log(`[${SERVICE_NAME}] Batch scheduler initialized (interval: ${BATCH_INTERVAL}ms)`);
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Failed to initialize service:`, error);
    process.exit(1);
  }
}

/**
 * グレースフルシャットダウン
 */
async function gracefulShutdown(signal) {
  console.log(`[${SERVICE_NAME}] ${signal} received, shutting down gracefully...`);

  try {
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

// サービス起動
main();
