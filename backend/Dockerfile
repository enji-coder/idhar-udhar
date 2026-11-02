# Production API image. Build from the repository root:
#   docker build -f backend/Dockerfile -t idhar-udhar-backend .
# Context must be the repo root so records_database/migrations can be included.
FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY backend/package.json backend/package-lock.json ./
RUN npm ci

COPY backend/nest-cli.json backend/tsconfig.json backend/tsconfig.build.json ./
COPY backend/src ./src

RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV MIGRATIONS_DIR=/app/records_database/migrations

RUN apk add --no-cache python3 make g++

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist
COPY backend/scripts ./scripts
COPY backend/rds-global-bundle.pem /app/certs/rds-global-bundle.pem
COPY records_database/migrations ./records_database/migrations

# Same pin as the migration image: production checksums must match the copied bytes.
RUN node --input-type=module -e "import { readFileSync } from 'node:fs'; import { PRODUCTION_FILE_CHECKSUMS, sha256Hex } from './scripts/migrate.mjs'; for (const [version, expected] of Object.entries(PRODUCTION_FILE_CHECKSUMS)) { const actual = sha256Hex(readFileSync('/app/records_database/migrations/' + version + '.sql')); if (actual !== expected) { process.stderr.write('Pinned migration checksum mismatch: ' + version + '\n'); process.exit(1); } }"

EXPOSE 3000

CMD ["node", "dist/main.js"]
