# Build stage: compilers and headers are only needed to build native gems (pg).
FROM ruby:4.0.8-slim AS build
ENV BUNDLE_WITHOUT=development:test
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential libpq-dev \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/cache

# Runtime stage: only the Postgres client library and the installed gems.
FROM ruby:4.0.8-slim
ENV BUNDLE_WITHOUT=development:test
RUN apt-get update \
  && apt-get install -y --no-install-recommends libpq5 \
  && rm -rf /var/lib/apt/lists/*
# Run as an ordinary user instead of root.
RUN groupadd --system --gid 1000 app \
  && useradd --system --uid 1000 --gid app --create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=app:app . .
USER app
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
