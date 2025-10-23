# Sample Application

Monorepo for Sample Application services using npm workspaces.

## Project Structure

```
app/
├── shared/           # Shared libraries (db, logger)
├── public/           # Public Web Service (customer-facing API)
├── admin/            # Admin Dashboard Service (internal management)
├── batch/            # Batch Processing Service (scheduled tasks)
└── package.json      # Root package.json with workspace configuration
```

## Services

### Public Web Service
- **Port**: 3000
- **Purpose**: Customer-facing REST API
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /api/users` - List users
  - `POST /api/users` - Create user
  - `GET /api/users/:id` - Get user by ID
  - `GET /api/stats` - Get statistics
  - `POST /api/stats` - Record statistic

### Admin Dashboard Service
- **Port**: 3000
- **Purpose**: Internal management and monitoring
- **Access**: VPN-only (not publicly accessible)
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /admin/users` - List all users with details
  - `DELETE /admin/users/:id` - Delete user
  - `GET /admin/stats` - System statistics
  - `POST /admin/stats/clear` - Clear old statistics
  - `GET /admin/database/info` - Database information

### Batch Processing Service
- **Execution**: Scheduled (daily at 3:00 AM JST via EventBridge)
- **Tasks**:
  1. Aggregate daily statistics
  2. Clean up old data (>90 days)
  3. Generate summary reports

## Development

### Prerequisites
- Node.js >= 20.0.0
- npm >= 10.0.0
- PostgreSQL 15.x

### Installation

```bash
# Install all dependencies (for all workspaces)
npm install
```

### Running Services Locally

```bash
# Set environment variables
cp .env.example .env
# Edit .env with your database credentials

# Run Public Web Service
npm run dev:public

# Run Admin Service
npm run dev:admin

# Run Batch Service (one-time execution)
npm run start:batch
```

### Environment Variables

Required environment variables (see `.env.example`):

```env
NODE_ENV=development
SERVICE_NAME=sample-app-public
LOG_LEVEL=info
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sampleappdb
DB_USER=postgres
DB_PASSWORD=your-password
```

## Docker

### Build Images

```bash
# Public Web Service
docker build -t sample-app-public -f public/Dockerfile .

# Admin Service
docker build -t sample-app-admin -f admin/Dockerfile .

# Batch Service
docker build -t sample-app-batch -f batch/Dockerfile .
```

### Run Containers

```bash
# Public Web Service
docker run -p 3000:3000 \
  -e DB_HOST=your-db-host \
  -e DB_PASSWORD=your-password \
  sample-app-public

# Admin Service
docker run -p 3001:3000 \
  -e DB_HOST=your-db-host \
  -e DB_PASSWORD=your-password \
  sample-app-admin

# Batch Service
docker run \
  -e DB_HOST=your-db-host \
  -e DB_PASSWORD=your-password \
  sample-app-batch
```

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Stats Table
```sql
CREATE TABLE stats (
  id SERIAL PRIMARY KEY,
  metric_name VARCHAR(100) NOT NULL,
  metric_value NUMERIC NOT NULL,
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Deployment

See [infrastructure documentation](../infra/cloudformation/README.md) for CloudFormation deployment.

Application deployment is automated via GitHub Actions:
- `.github/workflows/application.yml` - Builds Docker images and deploys to ECS

## Architecture

- **Framework**: Express.js
- **Database**: PostgreSQL (via pg connection pool)
- **Logging**: Winston (JSON format for CloudWatch)
- **Container**: Docker (multi-stage builds)
- **Orchestration**: ECS Fargate
- **Load Balancer**: ALB (for Public Web Service only)
- **Monitoring**: CloudWatch Logs and Metrics

## Health Checks

All services expose `/health` endpoint that returns:
- Service status
- Database connectivity
- Connection pool statistics
- Uptime and memory usage

Example response:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-24T12:00:00.000Z",
  "service": "public-web",
  "database": {
    "connected": true,
    "pool": {
      "totalCount": 5,
      "idleCount": 3,
      "waitingCount": 0
    }
  },
  "uptime": 3600,
  "memory": {
    "rss": 52428800,
    "heapTotal": 20971520,
    "heapUsed": 15728640
  }
}
```

## Monitoring

Logs are structured in JSON format for CloudWatch Logs Insights:

```json
{
  "level": "info",
  "message": "HTTP Request",
  "timestamp": "2025-10-24 12:00:00.000",
  "service": "public-web",
  "environment": "production",
  "method": "GET",
  "path": "/api/users",
  "statusCode": 200,
  "duration": "45ms"
}
```

Query logs in CloudWatch Logs Insights:
```
fields @timestamp, message, method, path, statusCode, duration
| filter level = "error"
| sort @timestamp desc
| limit 20
```

## License

Private - Internal use only
