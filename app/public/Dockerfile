# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files for all workspaces
COPY package.json ./
COPY shared/package.json ./shared/
COPY public/package.json ./public/

# Install dependencies
RUN npm install

# Copy source code
COPY shared ./shared
COPY public ./public

# Production stage
FROM node:20-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/shared ./shared
COPY --from=builder /app/public ./public

# Set working directory to public service
WORKDIR /app/public

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "src/index.js"]
