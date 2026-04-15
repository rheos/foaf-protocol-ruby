FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    default-libmysqlclient-dev \
    default-mysql-client \
    git \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 3002

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3002"]
