# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=19.4.0
FROM node:${NODE_VERSION}-slim as base

LABEL fly_launch_runtime="Node.js"

# Node.js app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV=production

ARG PNPM_VERSION=8.6.7
RUN npm install -g pnpm@$PNPM_VERSION


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build node modules
RUN apt-get update -qq && \
    apt-get install -y python-is-python3 pkg-config build-essential

# Install node modules
COPY --link package.json pnpm-lock.yaml yarn.lock ./
RUN pnpm install --frozen-lockfile --prod=false

# Copy application code
COPY --link . .

# Build application
RUN pnpm run build

# Remove development dependencies
RUN pnpm prune --prod


# Final stage for app image
FROM base

RUN apt-get update -y && apt-get install -y ca-certificates fuse3 sqlite3

# Copy built application
COPY --from=build /app /app
COPY --from=flyio/litefs:0.5 /usr/local/bin/litefs /usr/local/bin/litefs

# Setup sqlite3 on a separate volume
RUN mkdir -p /data
VOLUME /data
ENV DATABASE_URL="file:///data/feed.db"

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
ENTRYPOINT litefs mount
