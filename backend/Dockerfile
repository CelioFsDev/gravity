# ──────────────────────────────────────────────
# Gravity API — Dart AOT compiled Docker image
# ──────────────────────────────────────────────

# Build stage
FROM dart:stable AS build

WORKDIR /app

# Install dependencies first (layer caching).
COPY pubspec.* ./
RUN dart pub get

# Copy source and compile.
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# ──────────────────────────────────────────────
# Runtime stage — minimal image (~15MB)
# ──────────────────────────────────────────────
FROM scratch

COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 8080

ENTRYPOINT ["/app/bin/server"]
