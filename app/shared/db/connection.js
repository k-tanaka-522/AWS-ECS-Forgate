/**
 * Database Connection Module
 *
 * 目的: PostgreSQL接続プールの管理と接続取得
 * 設計: シングルトンパターンでコネクションプールを再利用
 */

const { Pool } = require('pg');

let pool = null;

/**
 * データベース接続プールの設定を取得
 *
 * @returns {Object} pg.Pool configuration
 */
function getPoolConfig() {
  return {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '5432', 10),
    database: process.env.DB_NAME || 'postgres',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,

    // Connection pool設定
    max: 20,                    // 最大接続数
    min: 2,                     // 最小接続数
    idleTimeoutMillis: 30000,   // アイドルタイムアウト（30秒）
    connectionTimeoutMillis: 10000,  // 接続タイムアウト（10秒）

    // エラーハンドリング
    statement_timeout: 30000,   // クエリタイムアウト（30秒）
    query_timeout: 30000,

    // SSL設定（RDSでは必要に応じて有効化）
    ssl: process.env.DB_SSL === 'true' ? {
      rejectUnauthorized: false
    } : false
  };
}

/**
 * データベース接続プールを取得
 * シングルトンパターンで1つのプールを使い回す
 *
 * @returns {Pool} pg.Pool instance
 */
function getPool() {
  if (!pool) {
    const config = getPoolConfig();

    // 必須環境変数チェック
    if (!config.host) {
      throw new Error('DB_HOST environment variable is required');
    }
    if (!config.password) {
      throw new Error('DB_PASSWORD environment variable is required');
    }

    pool = new Pool(config);

    // プールエラーハンドリング
    pool.on('error', (err) => {
      console.error('Unexpected database pool error:', err);
      // プールエラーが発生した場合、プールをリセット
      pool = null;
    });

    console.log(`Database connection pool created (host: ${config.host}, database: ${config.database})`);
  }

  return pool;
}

/**
 * データベース接続を取得
 *
 * @returns {Promise<Pool>} pg.Pool instance
 */
async function getDbConnection() {
  const currentPool = getPool();

  // 接続テスト
  try {
    const client = await currentPool.connect();
    console.log('Database connection successful');
    client.release();
    return currentPool;
  } catch (error) {
    console.error('Database connection failed:', error);
    throw error;
  }
}

/**
 * データベース接続プールをクローズ
 * アプリケーション終了時に呼び出す
 */
async function closeDbConnection() {
  if (pool) {
    await pool.end();
    pool = null;
    console.log('Database connection pool closed');
  }
}

/**
 * クエリを実行（簡易ヘルパー）
 *
 * @param {string} text - SQL query
 * @param {Array} params - Query parameters
 * @returns {Promise<Object>} Query result
 */
async function query(text, params) {
  const currentPool = getPool();
  const start = Date.now();

  try {
    const result = await currentPool.query(text, params);
    const duration = Date.now() - start;
    console.log(`Query executed in ${duration}ms: ${text.substring(0, 50)}...`);
    return result;
  } catch (error) {
    console.error('Query execution error:', error);
    console.error('Query:', text);
    console.error('Params:', params);
    throw error;
  }
}

module.exports = {
  getDbConnection,
  closeDbConnection,
  query,
  getPool
};
