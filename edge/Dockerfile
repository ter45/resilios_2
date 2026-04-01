# ══════════════════════════════════════════════
#  ResiliOS Edge — Dockerfile
#  Base: Ruby 3.3 slim para imagen liviana
#  Target: Raspberry Pi 4, mini-server, tablet Linux
# ══════════════════════════════════════════════

FROM ruby:3.3-slim AS base

# Dependencias del sistema (SQLite + build tools)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libsqlite3-dev \
      sqlite3 \
      curl \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Gems ──────────────────────────────────────
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# ── App ───────────────────────────────────────
COPY . .

# Precompile assets y setup DB
RUN bundle exec rails db:prepare RAILS_ENV=production || true

# Crear directorio de storage para SQLite
RUN mkdir -p /app/storage && chmod 777 /app/storage

EXPOSE 3000

# Health check endpoint
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
