# Stage 1: Build the application
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .

# Build with environment variables
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY

# Debug: Show environment variables
RUN echo "Building with VITE_SUPABASE_URL: $VITE_SUPABASE_URL"

RUN npm run build

# Debug: List build output
RUN ls -la /app/dist/
RUN ls -la /app/dist/assets/ || echo "No assets directory"

# Stage 2: Serve the application with Caddy
FROM caddy:2.8-alpine AS production
COPY --from=builder /app/dist /usr/share/caddy
# Ensure compatibility with platforms that expect Caddyfile at /assets
RUN mkdir -p /assets
COPY Caddyfile /assets/Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
# Explicitly use /assets/Caddyfile to match runtime expectations
CMD ["caddy", "run", "--config", "/assets/Caddyfile", "--adapter", "caddyfile"]