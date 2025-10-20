# ==============================================================================
# Admin Dashboard Service - Dockerfile
# ==============================================================================
# Multi-stage build for optimized image size
# ==============================================================================

# Build stage
FROM node:20-alpine AS base

WORKDIR /app

COPY package*.json ./
COPY admin/package*.json ./admin/
COPY shared/package*.json ./shared/

RUN npm ci --only=production --workspaces

COPY admin/ ./admin/
COPY shared/ ./shared/

# Production stage
FROM node:20-alpine

WORKDIR /app

COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/admin ./admin
COPY --from=base /app/shared ./shared

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

RUN chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "admin/src/index.js"]
