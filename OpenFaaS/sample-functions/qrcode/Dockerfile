FROM golang:1.10.4 as BUILDER
MAINTAINER john@johnmccabe.net

RUN apk --no-cache add make
WORKDIR /go/src/github.com/faas-and-furious/qrcode
COPY . /go/src/github.com/faas-and-furious/qrcode

RUN make

FROM alpine:3.9

COPY --from=builder /go/bin/qrcode /usr/bin
ADD https://github.com/alexellis/faas/releases/download/0.13.0/fwatchdog /usr/bin
RUN chmod +x /usr/bin/fwatchdog
COPY --from=builder /go/bin/qrcode /usr/bin
RUN chmod +x /usr/bin/qrcode

ENV fprocess "/usr/bin/qrcode"

CMD [ "/usr/bin/fwatchdog"]
