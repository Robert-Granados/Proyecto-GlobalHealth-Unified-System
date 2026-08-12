FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="GlobalHealth Web UI"
LABEL org.opencontainers.image.description="Panel grafico para el backend GlobalHealth API"

# Cache bust: copiamos primero la config y los estaticos.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html styles.css app.js /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]