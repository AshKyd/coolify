FROM node:18-alpine3.16 as build
WORKDIR /app

RUN apk add --no-cache curl
RUN curl -sL https://unpkg.com/@pnpm/self-installer | node

COPY . .
RUN pnpm install
RUN pnpm build

# Production build
FROM node:18-alpine3.16
WORKDIR /app
ENV NODE_ENV production
ARG TARGETPLATFORM

ENV PRISMA_QUERY_ENGINE_BINARY=/app/prisma-engines/query-engine \
  PRISMA_MIGRATION_ENGINE_BINARY=/app/prisma-engines/migration-engine \
  PRISMA_INTROSPECTION_ENGINE_BINARY=/app/prisma-engines/introspection-engine \
  PRISMA_FMT_BINARY=/app/prisma-engines/prisma-fmt \
  PRISMA_CLI_QUERY_ENGINE_TYPE=binary \
  PRISMA_CLIENT_ENGINE_TYPE=binary

COPY --from=coollabsio/prisma-engine:3.15 /prisma-engines/query-engine /prisma-engines/migration-engine /prisma-engines/introspection-engine /prisma-engines/prisma-fmt /app/prisma-engines/

RUN apk add --no-cache git git-lfs openssh-client curl jq cmake sqlite openssl psmisc
RUN curl -sL https://unpkg.com/@pnpm/self-installer | node

RUN mkdir -p ~/.docker/cli-plugins/
# https://download.docker.com/linux/static/stable/
RUN curl -SL https://cdn.coollabs.io/bin/$TARGETPLATFORM/docker-20.10.9 -o /usr/bin/docker
# https://github.com/docker/compose/releases
# Reverted to 2.6.1 because of this https://github.com/docker/compose/issues/9704. 2.9.0 still has a bug.
RUN curl -SL https://cdn.coollabs.io/bin/$TARGETPLATFORM/docker-compose-linux-2.6.1 -o ~/.docker/cli-plugins/docker-compose
RUN chmod +x ~/.docker/cli-plugins/docker-compose /usr/bin/docker

RUN (curl -sSL "https://github.com/buildpacks/pack/releases/download/v0.27.0/pack-v0.27.0-linux.tgz" | tar -C /usr/local/bin/ --no-same-owner -xzv pack)

COPY --from=build /app/apps/api/build/ .
COPY --from=build /app/apps/ui/build/ ./public
COPY --from=build /app/apps/api/prisma/ ./prisma
COPY --from=build /app/apps/api/package.json .
COPY --from=build /app/docker-compose.yaml .

RUN pnpm install -p

EXPOSE 3000
ENV CHECKPOINT_DISABLE=1
CMD pnpm start