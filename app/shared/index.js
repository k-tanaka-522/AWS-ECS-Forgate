/**
 * Shared library index
 * Exports common utilities for all services
 */

const db = require('./db');
const logger = require('./logger');

module.exports = {
  db,
  logger,
};
