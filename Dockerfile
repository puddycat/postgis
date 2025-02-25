#
# postgres/Dockerfile
#
# raymondstrose@hotmail.com
#
#   Create a PostgeSQL Docker image.
#
#   docker build -f Dockerfile  \
#       --build-arg BASE_IMAGE="postgis/postgis" \
#       --build-arg BASE_IMAGE_TAG="17-3.5" \
#       --build-arg POSTGRES_VERSION="17-3.5" \
#       -t raymondstrose/postgis:17-3.5 .
#

ARG	BASE_IMAGE="postgis/postgis"
ARG	BASE_IMAGE_TAG="17-3.5"
#ARG	POSTGRES_VERSION="13.1"
ARG	POSTGRES_HTTP_PORT="8080"
ARG	POSTGRES_EXTERNAL_HTTP_PORT="8080"

FROM $BASE_IMAGE:$BASE_IMAGE_TAG
LABEL MAINTAINER=raymondstrose@hotmail.com

ARG	POSTGRES_HTTP_PORT

EXPOSE ${POSTGRES_HTTP_PORT}
EXPOSE 5432
