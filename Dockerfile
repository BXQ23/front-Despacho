# ─────────────────────────────────────────────
# STAGE 1 — Build
# Node.js Alpine para instalar dependencias y
# compilar la aplicación React con Vite.
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copiamos package files primero para aprovechar caché de capas.
# Si package.json no cambia, npm ci no se re-ejecuta.
COPY package*.json ./
RUN npm ci --silent

# Copiamos el resto del código fuente
COPY . .

# Variable de build: URL del backend (EC2 privada).
# Se inyecta en tiempo de build como variable de entorno de Vite.
ARG VITE_API_URL=http://localhost:8080
ENV VITE_API_URL=$VITE_API_URL

# Compilar la aplicación (genera /app/dist)
RUN npm run build

# ─────────────────────────────────────────────
# STAGE 2 — Runtime
# Nginx Alpine sirve los archivos estáticos.
# Imagen final muy pequeña (~25 MB).
# ─────────────────────────────────────────────
FROM nginx:1.25-alpine

# Mínimo privilegio: nginx por defecto ya corre como nginx (no root)
# para los workers, pero el proceso master sí usa root para bind :80.
# Usamos el puerto 8080 para poder correr completamente sin root.
RUN sed -i 's/listen       80;/listen       8080;/' /etc/nginx/conf.d/default.conf \
    && sed -i 's/listen  \[::\]:80 default_server;//' /etc/nginx/conf.d/default.conf || true

# Copiamos el build de React al directorio de Nginx
COPY --from=builder /app/dist /usr/share/nginx/html

# Configuración de Nginx para React Router (SPA — Single Page Application)
# Redirige todas las rutas al index.html para que React Router funcione
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
