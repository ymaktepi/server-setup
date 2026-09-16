FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

run apt-get update
run apt-get install -y \
  ca-certificates \
  curl \
  debootstrap \
  skopeo \
  umoci \
  tar \
  zstd
