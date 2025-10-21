FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY packages/batch-processing/package*.json ./packages/batch-processing/
COPY packages/shared/package*.json ./packages/shared/

RUN npm ci --workspaces

COPY packages/batch-processing ./packages/batch-processing
COPY packages/shared ./packages/shared

RUN npm run build --workspace=packages/shared
RUN npm run build --workspace=packages/batch-processing

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/packages/batch-processing/dist ./dist
COPY --from=builder /app/packages/batch-processing/package*.json ./
COPY --from=builder /app/node_modules ./node_modules

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs

CMD ["node", "dist/jobs/stock-alert.job.js"]
