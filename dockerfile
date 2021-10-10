FROM alpine:3.14

RUN apk add --no-cache curl bash && \
    addgroup -S ddnsgroup && adduser -S appddns -G ddnsgroup

WORKDIR /app
RUN mkdir config && \
    chown appddns:ddnsgroup config

COPY --chown=appddns:ddnsgroup cloudflare-ddns.sh /app

RUN chmod +x cloudflare-ddns.sh

USER appddns

ENTRYPOINT ["./cloudflare-ddns.sh", "./config/cloudflare_domain.config"]