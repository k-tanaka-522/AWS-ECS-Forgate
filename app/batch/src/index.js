const { logger, db } = require('@sample-app/shared');

/**
 * Batch Processing Service
 * Scheduled to run daily at 3:00 AM JST via EventBridge
 *
 * Tasks:
 * 1. Aggregate daily statistics
 * 2. Clean up old data (older than 90 days)
 * 3. Generate summary reports
 */

/**
 * Aggregate daily statistics
 */
async function aggregateDailyStats() {
  logger.info('Starting daily statistics aggregation');

  try {
    // Count total users
    const userCountResult = await db.query('SELECT COUNT(*) as count FROM users');
    const userCount = parseInt(userCountResult.rows[0].count, 10);

    // Record user count statistic
    await db.query(
      'INSERT INTO stats (metric_name, metric_value) VALUES ($1, $2)',
      ['daily_user_count', userCount]
    );

    // Count users created today
    const newUsersResult = await db.query(
      "SELECT COUNT(*) as count FROM users WHERE created_at >= CURRENT_DATE"
    );
    const newUsersCount = parseInt(newUsersResult.rows[0].count, 10);

    await db.query(
      'INSERT INTO stats (metric_name, metric_value) VALUES ($1, $2)',
      ['daily_new_users', newUsersCount]
    );

    // Count stats recorded today
    const statsCountResult = await db.query(
      "SELECT COUNT(*) as count FROM stats WHERE recorded_at >= CURRENT_DATE"
    );
    const statsCount = parseInt(statsCountResult.rows[0].count, 10);

    await db.query(
      'INSERT INTO stats (metric_name, metric_value) VALUES ($1, $2)',
      ['daily_stats_count', statsCount]
    );

    logger.info('Daily statistics aggregated', {
      userCount,
      newUsersCount,
      statsCount,
    });

    return {
      success: true,
      userCount,
      newUsersCount,
      statsCount,
    };
  } catch (error) {
    logger.error('Failed to aggregate daily statistics', {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

/**
 * Clean up old data (older than 90 days)
 */
async function cleanupOldData() {
  logger.info('Starting old data cleanup');

  try {
    const daysToKeep = 90;

    // Delete old stats
    const statsResult = await db.query(
      "DELETE FROM stats WHERE recorded_at < NOW() - INTERVAL '90 days' RETURNING id"
    );

    const deletedStatsCount = statsResult.rowCount;

    logger.info('Old data cleaned up', {
      deletedStatsCount,
      daysToKeep,
    });

    // Record cleanup statistic
    await db.query(
      'INSERT INTO stats (metric_name, metric_value) VALUES ($1, $2)',
      ['cleanup_deleted_stats', deletedStatsCount]
    );

    return {
      success: true,
      deletedStatsCount,
    };
  } catch (error) {
    logger.error('Failed to clean up old data', {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

/**
 * Generate summary report
 */
async function generateSummaryReport() {
  logger.info('Generating summary report');

  try {
    // Get aggregated statistics by metric name
    const metricsResult = await db.query(`
      SELECT
        metric_name,
        COUNT(*) as count,
        AVG(metric_value) as avg_value,
        MIN(metric_value) as min_value,
        MAX(metric_value) as max_value,
        MIN(recorded_at) as first_recorded,
        MAX(recorded_at) as last_recorded
      FROM stats
      WHERE recorded_at >= NOW() - INTERVAL '7 days'
      GROUP BY metric_name
      ORDER BY count DESC
    `);

    // Get user growth statistics
    const userGrowthResult = await db.query(`
      SELECT
        DATE(created_at) as date,
        COUNT(*) as new_users
      FROM users
      WHERE created_at >= NOW() - INTERVAL '7 days'
      GROUP BY DATE(created_at)
      ORDER BY date DESC
    `);

    const report = {
      generatedAt: new Date().toISOString(),
      period: 'Last 7 days',
      metrics: metricsResult.rows,
      userGrowth: userGrowthResult.rows,
    };

    logger.info('Summary report generated', {
      metricsCount: metricsResult.rowCount,
      userGrowthDays: userGrowthResult.rowCount,
    });

    // Log the report (in production, this would be sent to S3 or CloudWatch)
    logger.info('Summary Report', { report: JSON.stringify(report, null, 2) });

    return report;
  } catch (error) {
    logger.error('Failed to generate summary report', {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

/**
 * Main batch processing function
 */
async function runBatchProcessing() {
  const startTime = Date.now();
  logger.info('Batch processing started');

  let results = {
    success: false,
    tasks: {},
    duration: 0,
    errors: [],
  };

  try {
    // Initialize database connection
    db.initialize();

    // Test database connection
    const isConnected = await db.testConnection();
    if (!isConnected) {
      throw new Error('Failed to connect to database');
    }

    // Run batch tasks sequentially
    try {
      results.tasks.aggregateStats = await aggregateDailyStats();
    } catch (error) {
      results.errors.push({
        task: 'aggregateStats',
        error: error.message,
      });
    }

    try {
      results.tasks.cleanupOldData = await cleanupOldData();
    } catch (error) {
      results.errors.push({
        task: 'cleanupOldData',
        error: error.message,
      });
    }

    try {
      results.tasks.generateReport = await generateSummaryReport();
    } catch (error) {
      results.errors.push({
        task: 'generateReport',
        error: error.message,
      });
    }

    // Close database connection
    await db.close();

    results.success = results.errors.length === 0;
    results.duration = Date.now() - startTime;

    logger.info('Batch processing completed', {
      success: results.success,
      duration: `${results.duration}ms`,
      tasksCompleted: Object.keys(results.tasks).length,
      errors: results.errors.length,
    });

    // Exit with appropriate code
    process.exit(results.success ? 0 : 1);
  } catch (error) {
    results.errors.push({
      task: 'main',
      error: error.message,
    });

    logger.error('Batch processing failed', {
      error: error.message,
      stack: error.stack,
      duration: `${Date.now() - startTime}ms`,
    });

    // Ensure database connection is closed
    try {
      await db.close();
    } catch (closeError) {
      logger.error('Failed to close database connection', {
        error: closeError.message,
      });
    }

    process.exit(1);
  }
}

// Run batch processing
runBatchProcessing();
