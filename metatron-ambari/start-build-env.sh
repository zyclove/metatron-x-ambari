#!/usr/bin/env bash
#
# Start a Docker-based build environment

set -e -u

cd "$(dirname "$0")"

# OS to build on
: ${BUILD_OS:=centos7}

# Directory with Ambari source
: ${AMBARI_DIR:=$(pwd -P)}

# Maven version
: ${MAVEN_VERSION:=3.6.0}

docker build -t ambari-build-base:${BUILD_OS} dev-support/docker/${BUILD_OS}
docker build -t ambari-build:${BUILD_OS} --build-arg BUILD_OS="${BUILD_OS}" --build-arg MAVEN_VERSION="${MAVEN_VERSION}" dev-support/docker/common

USER_NAME=${SUDO_USER:=$USER}
USER_ID=$(id -u "${USER_NAME}")
GROUP_ID=$(id -g "${USER_NAME}")
USER_TAG="ambari-build-${USER_NAME}-${USER_ID}:${BUILD_OS}"

docker build -t "$USER_TAG" - <<UserSpecificDocker
FROM ambari-build:${BUILD_OS}
RUN groupadd --non-unique -g ${GROUP_ID} ${USER_NAME}
RUN useradd -g ${GROUP_ID} -u ${USER_ID} -k /root -m ${USER_NAME}
ENV HOME /home/${USER_NAME}
UserSpecificDocker

TTY_MODE="-t -i"
if [ "$#" -gt 0 ]; then
  TTY_MODE=""
fi

# By mapping the .m2 directory you can do an mvn install from
# within the container and use the result on your normal
# system.  This also allows a significant speedup in subsequent
# builds, because the dependencies are downloaded only once.
docker run --rm=true $TTY_MODE \
  -u "${USER_NAME}" \
  -h "${BUILD_OS}" \
  -v "${AMBARI_DIR}:/home/${USER_NAME}/src:delegated" \
  -v "${HOME}/.m2:/home/${USER_NAME}/.m2:cached" \
  -w "/home/${USER_NAME}/src" \
  "$USER_TAG" \
  "$@"
