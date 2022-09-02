#FROM alpine
# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && apk add po4a make


FROM debian
RUN apt-get update 
RUN apt-get -y install make po4a
WORKDIR work

CMD cd translation && make update
