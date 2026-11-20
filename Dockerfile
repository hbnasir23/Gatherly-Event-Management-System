# Gatherly web tier: static page served by Nginx
FROM nginx:1.27-alpine

COPY app/ /usr/share/nginx/html/

# Lightweight health endpoint used by the load balancer
RUN printf 'server {\n  listen 80;\n  root /usr/share/nginx/html;\n  location / { try_files $uri /index.html; }\n  location = /healthz { return 200 "ok"; add_header Content-Type text/plain; }\n}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost/healthz || exit 1
