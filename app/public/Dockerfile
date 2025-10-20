# ==============================================================================
# Public Web Service - Dockerfile
# ==============================================================================
# Multi-stage build for optimized image size
# ==============================================================================

# Build stage
FROM node:20-alpine AS base

# Set working directory
WORKDIR /app

# Copy root package.json and package-lock.json
COPY package*.json ./

# Copy workspace package.json files
COPY public/package*.json ./public/
COPY shared/package*.json ./shared/

# Install all dependencies (including workspaces)
RUN npm ci --only=production --workspaces

# Copy application code
COPY public/ ./public/
COPY shared/ ./shared/

# Production stage
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy dependencies from build stage
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/public ./public
COPY --from=base /app/shared ./shared

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "public/src/index.js"]
