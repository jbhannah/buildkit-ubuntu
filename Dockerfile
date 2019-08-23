FROM ubuntu:18.04 AS curl
ARG BUILDKIT_VERSION=v0.6.1

RUN apt-get update \
    && apt-get install -y curl \
    && curl -L https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz | tar xzC /usr

FROM ubuntu:18.04
COPY --from=curl /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crl
COPY --from=curl /usr/bin/buildkit-runc /usr/bin/buildkitd /usr/bin/
COPY --from=curl /usr/bin/buildctl /usr/bin/_buildctl
COPY ./bin/buildctl-daemonless.sh /usr/bin/buildctl
