FROM node:20-alpine

WORKDIR /app

# Copy shared library
COPY shared/ /app/shared/

# Copy batch service
COPY batch/package*.json ./
RUN npm ci --only=production

COPY batch/src/ ./src/

CMD ["node", "src/index.js"]
