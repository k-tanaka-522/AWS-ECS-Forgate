# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files for all workspaces
COPY package.json ./
COPY shared/package.json ./shared/
COPY batch/package.json ./batch/

# Install dependencies
RUN npm install

# Copy source code
COPY shared ./shared
COPY batch ./batch

# Production stage
FROM node:20-alpine

WORKDIR /app

# Copy from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/shared ./shared
COPY --from=builder /app/batch ./batch

# Set working directory to batch service
WORKDIR /app/batch

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Start batch processing
CMD ["node", "src/index.js"]
