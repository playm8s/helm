FROM docker.io/node:24-alpine

USER root

RUN set -exu \
  && apk add --no-cache \
    make \
    bash \
    curl \
    python3 \
    g++ \
    gcc \
    git \
    yq

RUN set -exu \
  && curl -sSL https://github.com/pulumi/crd2pulumi/releases/download/v1.6.0/crd2pulumi-v1.6.0-linux-amd64.tar.gz \
      | tar -xzv -C /usr/bin crd2pulumi \
  && curl -sSL https://github.com/arttor/helmify/releases/download/v0.4.19/helmify_Linux_x86_64.tar.gz \
      | tar -xzv -C /usr/bin helmify

WORKDIR /work

ENTRYPOINT ["/bin/bash"]
