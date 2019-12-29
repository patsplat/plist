FROM ruby:2.5.3-alpine3.8
RUN apk update && apk add git

WORKDIR /app
COPY . .
CMD sh
