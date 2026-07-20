#!/bin/bash
set -e

# Script de instalacion para maquinas Ubuntu nuevas.
# Descarga el repositorio publico y ejecuta el playbook de Ansible.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/jalucenyo/workspace-dev/main/install.sh | sudo bash
#   ./install.sh

REPO_OWNER="jalucenyo"
REPO_NAME="workspace-dev"
REPO_BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"
ZIP_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REPO_BRANCH}.zip"

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

# Funcion para descargar el repo publico desde GitHub
descargar_repo() {
    echo "Descargando repositorio desde GitHub..."
    TMP_DIR=$(mktemp -d)

    curl -fsSL -L "$ZIP_URL" -o "${TMP_DIR}/repo.zip"

    echo "Extrayendo repositorio..."
    unzip -q "${TMP_DIR}/repo.zip" -d "${TMP_DIR}"

    # El directorio extraido tiene un nombre como workspace-dev-main
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
# El playbook pedira el PAT de GitHub interactivamente si se quiere autenticar gh.
echo "Ejecutando playbook de Ansible..."
ansible-playbook site.yml

echo ""
echo "Instalacion completada."
