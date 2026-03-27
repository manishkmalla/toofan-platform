# ─────────────────────────────────────────────
#  TooFan Backend — Dockerfile
# ─────────────────────────────────────────────
FROM node:18-alpine AS base

WORKDIR /app

# Install dependencies only
COPY package*.json ./
RUN npm ci --only=production

# Generate Prisma client
COPY prisma ./prisma
RUN npx prisma generate

# Copy source
COPY src ./src

EXPOSE 5000

CMD ["node", "src/index.js"]
