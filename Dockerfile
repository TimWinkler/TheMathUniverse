FROM nginx:alpine

# Copy web export files
COPY build/web/ /usr/share/nginx/html/

# Custom nginx config for correct MIME types and caching
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
