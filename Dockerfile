FROM alpine
RUN apk add perl-yaml-tiny po4a
WORKDIR /work

CMD cd translation && po4a -f -v ./po4a.cfg
