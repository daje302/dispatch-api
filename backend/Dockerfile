# Imagen base con Node 20
FROM node:20-slim

WORKDIR /app

# Instala dependencias (usa el lockfile para builds reproducibles)
COPY package*.json ./
RUN npm ci --omit=dev

# Copia el código de la aplicación
COPY . .

# Render asigna el puerto automáticamente (PORT env)
ENV NODE_ENV=production
EXPOSE 4000

CMD ["node", "src/index.js"]