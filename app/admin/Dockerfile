FROM node:20-alpine

WORKDIR /app

# Copy shared library
COPY shared/ /app/shared/

# Copy admin service
COPY admin/package*.json ./
RUN npm ci --only=production

COPY admin/src/ ./src/

EXPOSE 3000

CMD ["node", "src/index.js"]
