FROM        wener/base:bash

RUN apk --no-cache add nginx nginx-mod-stream && \
    chown -R nginx:www-data /var/lib/nginx && \
    mkdir -p /run/nginx/

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
