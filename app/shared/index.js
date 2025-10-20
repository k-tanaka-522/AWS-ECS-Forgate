/**
 * Shared Module Entry Point
 *
 * 共通ライブラリのエクスポート
 */

const { getDbConnection, closeDbConnection, query, getPool } = require('./db/connection');

module.exports = {
  db: {
    getConnection: getDbConnection,
    closeConnection: closeDbConnection,
    query,
    getPool
  }
};
