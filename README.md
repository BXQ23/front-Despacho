# Front Despacho — React + Vite

Frontend de la aplicación de gestión de despachos y ventas para Innovatech Chile.  
React 18 · Vite 5 · Tailwind CSS · Nginx · Docker · GitHub Actions CI/CD

---

## Tabla de contenidos

1. [Descripción](#descripción)
2. [Requisitos previos](#requisitos-previos)
3. [Variables de entorno](#variables-de-entorno)
4. [Ejecutar con Docker Compose](#ejecutar-con-docker-compose)
5. [Ejecutar en desarrollo local (sin Docker)](#ejecutar-en-desarrollo-local)
6. [Dockerfile (multi-stage)](#dockerfile-multi-stage)
7. [Pipeline CI/CD](#pipeline-cicd)
8. [Secrets de GitHub Actions](#secrets-de-github-actions)
9. [Arquitectura de red](#arquitectura-de-red)

---

## Descripción

Aplicación SPA (Single Page Application) que se comunica con los backends de Ventas y Despachos desplegados en la subred privada del EC2 backend.

**Puerto en producción:** `80` (Nginx escucha en 8080 internamente; el compose mapea 80→8080)  
**Stack:** React 18, React Router, Axios, TailwindCSS, SweetAlert2

---

## Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Docker | 24.x |
| Docker Compose | 2.x |
| Node.js | 20.x (solo para desarrollo local) |

---

## Variables de entorno

| Variable | Descripción | Ejemplo |
|---|---|---|
| `VITE_API_URL` | URL base del backend (inyectada en tiempo de **build**) | `http://10.0.2.100:8080` |
| `DOCKERHUB_USERNAME` | Usuario Docker Hub | `miusuario` |
| `BACKEND_URL` | URL backend (solo referencia en el compose) | `http://10.0.2.100:8080` |

> **Importante:** Vite incrusta las variables `VITE_*` en el bundle estático durante el build.  
> No se pueden cambiar en runtime sin reconstruir la imagen.  
> La URL del backend se pasa como `--build-arg` en el pipeline CI/CD.

Copia `.env.example` a `.env`:
```bash
cp .env.example .env
```

---

## Ejecutar con Docker Compose

```bash
# 1. Clonar el repositorio
git clone https://github.com/TU_USUARIO/front-despacho.git
cd front-despacho

# 2. Configurar variables
cp .env.example .env
# Editar .env

# 3. Levantar
docker compose up -d

# 4. Abrir en el navegador
# http://<IP-EC2-FRONTEND>

# 5. Ver logs
docker compose logs -f front-despacho

# 6. Detener
docker compose down
```

---

## Ejecutar en desarrollo local

```bash
# Instalar dependencias
npm install

# Iniciar servidor de desarrollo (con hot-reload)
npm run dev
# Acceder en http://localhost:5173

# Build de producción
npm run build
# Los archivos quedan en /dist
```

---

## Dockerfile (multi-stage)

```
Stage 1 (builder)  →  node:20-alpine
  - npm ci (instalación limpia y reproducible)
  - VITE_API_URL inyectada como ARG de build
  - npm run build → genera /app/dist

Stage 2 (runtime)  →  nginx:1.25-alpine (~25 MB)
  - Copia solo /app/dist (no node_modules)
  - Nginx sirve archivos estáticos
  - Configurado para React Router (SPA)
  - Corre en puerto 8080 (sin privilegios root)
```

**Ventajas del multi-stage para frontend:**
- La imagen final no contiene Node.js, npm ni el código fuente
- Solo los archivos HTML/CSS/JS compilados → imagen muy pequeña (~35 MB)
- `npm ci` en lugar de `npm install` → builds reproducibles

---

## Pipeline CI/CD

```
Push a rama deploy
        │
        ▼
┌───────────────────────────────┐
│  JOB 1: build-push            │
│  1. Checkout                  │
│  2. Login DockerHub           │
│  3. Build con VITE_API_URL    │  ← URL del backend desde secret
│  4. Push :latest + :sha-XXXX  │
└──────────────┬────────────────┘
               │
               ▼
┌───────────────────────────────┐
│  JOB 2: deploy                │
│  1. SSH → EC2 Frontend        │
│  2. docker compose pull       │
│  3. compose up --no-deps      │
│  4. image prune               │
└───────────────────────────────┘
```

---

## Secrets de GitHub Actions

Configurar en **Settings → Secrets and variables → Actions**:

| Secret | Descripción |
|---|---|
| `DOCKERHUB_USERNAME` | Usuario Docker Hub |
| `DOCKERHUB_TOKEN` | Token de acceso Docker Hub |
| `EC2_FRONTEND_HOST` | IP pública del EC2 frontend |
| `EC2_USERNAME` | Usuario SSH (`ec2-user` / `ubuntu`) |
| `EC2_SSH_KEY` | Clave privada `.pem` completa |
| `BACKEND_URL` | URL del backend en subred privada (ej: `http://10.0.2.100:8080`) |

---

## Arquitectura de red

```
Internet
    │
    │  Puerto 80 (HTTP)
    ▼
┌─────────────────────────────────┐
│  EC2 Frontend (subred pública)  │
│  Contenedor: front-despacho     │
│  Nginx → :80 → :8080            │
└────────────────┬────────────────┘
                 │  Peticiones API (Security Group)
                 │  Solo desde EC2 Frontend permitido
                 ▼
┌─────────────────────────────────┐
│  EC2 Backend (subred privada)   │
│  back-ventas    → :8080         │
│  back-despachos → :8081         │
│  mysql          → :3306 (solo   │
│                   localhost)    │
└─────────────────────────────────┘
```

Solo el EC2 Frontend es accesible desde Internet.  
El EC2 Backend solo acepta conexiones desde la IP del EC2 Frontend (Security Group).

---

## Estructura del repositorio

```
front-despacho/
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # Pipeline CI/CD
├── src/                    # Código fuente React
│   ├── componentes/
│   ├── Routes/
│   └── main.jsx
├── public/
├── Dockerfile              # Multi-stage (Node → Nginx)
├── nginx.conf              # Config Nginx para SPA
├── docker-compose.yml      # Stack frontend
├── .env.example
├── package.json
├── vite.config.js
└── README.md
```
