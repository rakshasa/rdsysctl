ARG ALPINE_VERSION=3.15


FROM "scratch" AS entrypoint

COPY ./entrypoint.sh /


FROM "alpine:${ALPINE_VERSION}" AS test_wait

ARG RUN_COMMAND="sleep 1000000"
ENV RUN_COMMAND="${RUN_COMMAND}"

RUN set -xe; \
  apk add --no-cache \
    bash

COPY --from=entrypoint /entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
