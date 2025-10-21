FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY packages/admin-dashboard/package*.json ./packages/admin-dashboard/
COPY packages/shared/package*.json ./packages/shared/

RUN npm ci --workspaces

COPY packages/admin-dashboard ./packages/admin-dashboard
COPY packages/shared ./packages/shared

RUN npm run build --workspace=packages/shared
RUN npm run build --workspace=packages/admin-dashboard

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/packages/admin-dashboard/dist ./dist
COPY --from=builder /app/packages/admin-dashboard/package*.json ./
COPY --from=builder /app/node_modules ./node_modules

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs

EXPOSE 3001

CMD ["node", "dist/index.js"]
