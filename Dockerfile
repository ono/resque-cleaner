from ruby:3.2
RUN apt update && apt install -y redis && apt clean
COPY . /app/
WORKDIR /app
RUN bundle install
