FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# Set Node.js environment for New Relic
ENV NODE_ENV=production

CMD ["node", "-r", "newrelic", "index.js"]