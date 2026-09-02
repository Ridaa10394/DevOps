# Hello World - Node.js application
FROM node:20-alpine

WORKDIR /app

# Copy manifests first so npm install is cached across code changes
COPY package.json ./
RUN npm install --omit=dev

# Copy the application source
COPY server.js ./

EXPOSE 3000
CMD ["node", "server.js"]
