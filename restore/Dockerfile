#
# postgis/restore/Dockerfile
#
#   Create a PostgeSQL Docker restore container image.
#
#   docker build -f Dockerfile  \
#       --build-arg BASE_IMAGE="raymondstrose/postgis" \
#       --build-arg BASE_IMAGE_TAG="13.1" \
#       -t home/postgis-backup:13.1 .
#

ARG	BASE_IMAGE="raymondstrose/postgis"
ARG	BASE_IMAGE_TAG="17.2"
#ARG	BASE_IMAGE_TAG="13.1"
ARG	POSTGRES_HTTP_PORT="8080"
ARG	POSTGRES_EXTERNAL_HTTP_PORT="8080"

FROM $BASE_IMAGE:$BASE_IMAGE_TAG
LABEL MAINTAINER=raymondstrose@hotmail.com

ARG	POSTGRES_HTTP_PORT

COPY pg_backup.config /usr/bin/
COPY pg_backup.sh /usr/bin/
COPY pg_backup_rotated.sh /usr/bin/
RUN apt-get upgrade -y
#RUN apt-get update -y
#RUN apt-get install -y inetutils-ping nmap dnsutils

EXPOSE ${POSTGRES_HTTP_PORT}

ENTRYPOINT ["/usr/bin/pg_backup.sh"]
