FROM ruby:4.0
RUN apt-get update && apt-get install -y redis-server && apt-get clean
COPY . /app/
WORKDIR /app
RUN bundle install
