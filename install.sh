#!/bin/bash
set -e

# Script de instalacion para maquinas Ubuntu nuevas.
# Uso:
#   ./install.sh
#   GITHUB_TOKEN=ghp_xxx ./install.sh
#   sudo ./install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detectar si estamos en Ubuntu
if [ ! -f /etc/os-release ]; then
    echo "Este script solo esta preparado para Ubuntu."
    exit 1
fi

source /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    echo "Este script solo esta preparado para Ubuntu. Detectado: $ID"
    exit 1
fi

# Actualizar repositorios e instalar dependencias
if ! command -v ansible-playbook &> /dev/null; then
    echo "Instalando Ansible..."
    apt-get update
    apt-get install -y ansible git curl wget
fi

# Entrar al directorio del playbook
cd "$SCRIPT_DIR"

# Ejecutar el playbook
# Si GITHUB_TOKEN esta definido, se pasa al entorno de ansible-playbook
# para que el playbook autentique gh automaticamente.
# Si no esta definido, el playbook pedira el PAT interactivamente.
echo "Ejecutando playbook de Ansible..."
if [ -n "$GITHUB_TOKEN" ]; then
    export GITHUB_TOKEN
    echo "Usando GITHUB_TOKEN del entorno para autenticar gh."
fi

ansible-playbook site.yml

echo ""
echo "Instalacion completada."
