FROM golang:1.22 as builder

WORKDIR /project

COPY app/ /project

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM alpine:3.19

WORKDIR /project

COPY --from=builder /project/app .

EXPOSE 8080

CMD ["./app"]