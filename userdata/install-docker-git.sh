#!/bin/bash

# Script de User Data para configurar instancias EC2 con Docker, Docker Compose y Git
# Compatible con Ubuntu en AWS EC2
# Versión: 1.0
# Fecha: 2026-05-09

set -e  # Salir si hay algún error

# Función para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/user-data.log
}

log "Iniciando configuración de instancia EC2..."

# Actualizar el sistema
log "Actualizando el sistema..."
apt-get update -y
apt-get upgrade -y

# Instalar dependencias básicas
log "Instalando dependencias básicas..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    unzip \
    wget \
    vim \
    htop \
    jq

# Instalar Docker
log "Instalando Docker..."

# Agregar clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Agregar repositorio de Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Actualizar índices de paquetes
apt-get update -y

# Instalar Docker Engine
apt-get install -y docker-ce docker-ce-cli containerd.io

# Iniciar y habilitar Docker
systemctl start docker
systemctl enable docker

log "Docker instalado y habilitado."

log "Instalando Docker Compose..."

DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)

curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose

ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

docker-compose --version

log "Docker Compose instalado. Versión: $(docker-compose --version)"

log "Configurando Docker para uso sin sudo..."

groupadd -f docker

usermod -aG docker ubuntu

log "Usuario ubuntu agregado al grupo docker."

log "Asegurando que Git esté instalado y actualizado..."
apt-get install -y git

git --version

log "Git instalado. Versión: $(git --version)"

log "Instalando herramientas adicionales..."

apt-get install -y \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    awscli

apt-get clean
apt-get autoremove -y

log "Instalación completada exitosamente."

# Levantar contenedor Nginx
log "Levantando contenedor Nginx..."
docker run --name mi-nginx -p 80:80 -d nginx

# Esperar a que el contenedor esté listo
sleep 5

# Verificar que el contenedor está ejecutándose
log "Verificando estado del contenedor..."
if docker ps | grep -q mi-nginx; then
    log "✅ Contenedor Nginx está ejecutándose correctamente"
else
    log "❌ Error: Contenedor Nginx no está ejecutándose"
fi

# Verificar conectividad
log "Verificando conectividad de Nginx..."
if curl -f http://localhost:80 > /dev/null 2>&1; then
    log "✅ Nginx está respondiendo correctamente en puerto 80"
else
    log "❌ Error: Nginx no responde en puerto 80"
fi

log "Aplicación web desplegada exitosamente."

cat > /home/ubuntu/installation_complete.txt << EOF
Instalación completada: $(date)
Docker: $(docker --version)
Docker Compose: $(docker-compose --version)
Git: $(git --version)
Node.js: $(node --version)
NPM: $(npm --version)
AWS CLI: $(aws --version)

=== APLICACIÓN WEB ===
Estado: Desplegada
Contenedor Nginx: Ejecutándose en puerto 80
URL: http://localhost:80
URL ALB: http://<alb-dns-name>
Status: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:80)
EOF

chown ubuntu:ubuntu /home/ubuntu/installation_complete.txt

log "Archivo de verificación creado en /home/ubuntu/installation_complete.txt"

log "Configuración de instancia EC2 completada."

log "Script de user data finalizado."