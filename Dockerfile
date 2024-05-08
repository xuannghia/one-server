FROM traefik/whoami as whoami

FROM alpine/curl

COPY --from=whoami /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=whoami /etc/ssl/certs /etc/ssl/certs
COPY --from=whoami /whoami /whoami

ENTRYPOINT ["/whoami"]

EXPOSE 80
