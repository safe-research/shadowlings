FROM docker.io/library/node:18

# v0.8.0-ish
ARG TAG=e31b311cfd42cae9f5d71306f14e947bd70ee38e

RUN git clone https://github.com/eth-infinitism/bundler /src/bundler
WORKDIR /src/bundler
RUN git checkout ${TAG}
RUN git submodule init && git submodule update

RUN yarn && yarn preprocess
ENTRYPOINT ["yarn", "bundler"]
CMD []
