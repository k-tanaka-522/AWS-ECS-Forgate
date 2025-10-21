FROM node:20-alpine AS builder

WORKDIR /app

# Copy root package.json for workspaces
COPY package*.json ./
COPY packages/public-web/package*.json ./packages/public-web/
COPY packages/shared/package*.json ./packages/shared/

# Install dependencies
RUN npm ci --workspaces

# Copy source code
COPY packages/public-web ./packages/public-web
COPY packages/shared ./packages/shared

# Build
RUN npm run build --workspace=packages/shared
RUN npm run build --workspace=packages/public-web

# Production image
FROM node:20-alpine

WORKDIR /app

# Copy built files
COPY --from=builder /app/packages/public-web/dist ./dist
COPY --from=builder /app/packages/public-web/package*.json ./
COPY --from=builder /app/node_modules ./node_modules

# Run as non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs

EXPOSE 3000

CMD ["node", "dist/index.js"]
