#!/bin/bash
set -e

# Script de instalacion para maquinas Ubuntu nuevas.
# Uso:
#   ./install.sh
#   GITHUB_TOKEN=ghp_xxx ./install.sh
#   sudo GITHUB_TOKEN=ghp_xxx ./install.sh
#   curl -fsSL -H "Authorization: token $GITHUB_TOKEN" https://raw.githubusercontent.com/jalucenyo/workspace-dev/main/install.sh | sudo GITHUB_TOKEN=$GITHUB_TOKEN bash

REPO_OWNER="jalucenyo"
REPO_NAME="workspace-dev"
REPO_BRANCH="main"

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

# Funcion para descargar el repo privado desde GitHub
descargar_repo() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "ERROR: se necesita GITHUB_TOKEN para descargar el repositorio privado."
        echo "Ejecuta:"
        echo "  curl -fsSL -H \"Authorization: token \$GITHUB_TOKEN\" https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}/install.sh | sudo GITHUB_TOKEN=\$GITHUB_TOKEN bash"
        exit 1
    fi

    echo "Descargando repositorio privado desde GitHub..."
    TMP_DIR=$(mktemp -d)
    ZIP_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/zipball/${REPO_BRANCH}"

    curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" -L "$ZIP_URL" -o "${TMP_DIR}/repo.zip"

    echo "Extrayendo repositorio..."
    unzip -q "${TMP_DIR}/repo.zip" -d "${TMP_DIR}"

    # El directorio extraido tiene un nombre como jalucenyo-workspace-dev-abcdef
    EXTRACTED_DIR=$(find "${TMP_DIR}" -maxdepth 1 -type d | grep -v "^${TMP_DIR}$" | head -1)

    echo "${EXTRACTED_DIR}"
}

# Determinar el directorio del playbook
if [ -f "$(dirname "${BASH_SOURCE[0]}")/site.yml" ]; then
    # Estamos dentro del repo clonado
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Descargar el repo
    SCRIPT_DIR=$(descargar_repo)
fi

# Actualizar repositorios e instalar dependencias
if ! command -v ansible-playbook &> /dev/null; then
    echo "Instalando Ansible..."
    apt-get update
    apt-get install -y ansible git curl wget unzip
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
