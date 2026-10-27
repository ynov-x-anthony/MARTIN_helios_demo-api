FROM gcr.io/distroless/nodejs22-debian13:nonroot

WORKDIR /app

COPY --chown=65532:65532 package.json server.js ./

USER 65532:65532

EXPOSE 4000

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/nodejs/bin/node", "-e", "fetch('http://localhost:4000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

CMD ["server.js"]
