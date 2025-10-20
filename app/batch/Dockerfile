# ==============================================================================
# Batch Processing Service - Dockerfile
# ==============================================================================
# Multi-stage build for optimized image size
# ==============================================================================

# Build stage
FROM node:20-alpine AS base

WORKDIR /app

COPY package*.json ./
COPY batch/package*.json ./batch/
COPY shared/package*.json ./shared/

RUN npm ci --only=production --workspaces

COPY batch/ ./batch/
COPY shared/ ./shared/

# Production stage
FROM node:20-alpine

WORKDIR /app

COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/batch ./batch
COPY --from=base /app/shared ./shared

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

RUN chown -R nodejs:nodejs /app

USER nodejs

CMD ["node", "batch/src/index.js"]
