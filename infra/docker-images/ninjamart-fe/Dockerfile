FROM node:14-alpine AS builder

EXPOSE 3000
WORKDIR /app

# install app dependencies
COPY env/.env.develop /app/.env

RUN apk --no-cache add \
    g++ make python3 git \
    && yarn global add node-gyp \
    && rm -rf /var/cache/apk/*

ADD package.json yarn.lock /app/
RUN yarn --pure-lockfile

ADD . /app
RUN yarn build

CMD ["yarn", "start"]