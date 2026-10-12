FROM ruby:4.0.7-slim
RUN apt-get update && apt-get install -y build-essential libpq-dev
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]