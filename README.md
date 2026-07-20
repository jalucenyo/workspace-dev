# Entorno de desarrollo con Ansible

Playbook para instalar y configurar un entorno de desarrollo completo en Ubuntu, preparado para dos usuarios: `jalucenyo` (administrador) y `agent` (sin privilegios de sudo).

## Instalacion rapida en una maquina nueva

El script `install.sh` puede descargarse y ejecutarse directamente con `curl`. Solo necesitas un [PAT de GitHub](https://github.com/settings/tokens) con permisos de lectura sobre repositorios privados.

### 1. Con token de GitHub (autenticacion de gh automatica)

```bash
export GITHUB_TOKEN=ghp_TU_TOKEN
sudo GITHUB_TOKEN=$GITHUB_TOKEN bash -c "$(curl -fsSL -H \"Authorization: token $GITHUB_TOKEN\" https://raw.githubusercontent.com/jalucenyo/workspace-dev/main/install.sh)"
```

### 2. Sin token de GitHub (modo interactivo)

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/jalucenyo/workspace-dev/main/install.sh)"
```

> Sin token el script no podra descargar el repositorio privado. Necesitas el token para el one-liner.

### 3. Autenticacion de GitHub CLI

Si usas el one-liner con `GITHUB_TOKEN`, el playbook autenticara `gh` automaticamente para ambos usuarios.

Si no proporcionas el token, el playbook te lo pedira al inicio de forma interactiva.

## Estructura del proyecto

```
dev-install/
├── ansible.cfg
├── inventory/localhost.yml
├── group_vars/
│   └── all.yml              # variables publicas
├── site.yml                 # playbook principal
└── tasks/
    ├── system.yml           # dependencias, Docker, SSH, VS Code, GitHub CLI
    ├── users.yml            # usuarios y grupos
    ├── workspace.yml        # /projects compartido + bind mounts
    ├── ssh.yml              # claves SSH por usuario
    ├── git.yml              # git config por usuario
    ├── github_cli.yml       # autenticacion gh por usuario
    ├── node.yml             # FNM + Node.js por usuario
    ├── pnpm.yml             # pnpm por usuario
    ├── python.yml           # uv por usuario
    ├── agents.yml           # OpenCode y Claude Code por usuario
    └── portless.yml         # Portless por usuario
```

## Requisitos

- Ubuntu 24.04 o superior (testado en 26.04)
- Ansible instalado
- Conexion a Internet
- Usuario con privilegios de sudo (para ejecutar el playbook)

## Personalizacion

Edita `group_vars/all.yml` para adaptar los datos a tu entorno:

```yaml
---
dev_users:
  - name: jalucenyo
    git_name: "Jose Lucenyo"
    git_email: "1618926+jalucenyo@users.noreply.github.com"
  - name: agent
    git_name: "Agent"
    git_email: "agent@localhost"

projects_dir: /projects
projects_group: projects
node_version: "lts"
```

### Variables disponibles

| Variable | Descripcion | Ejemplo |
|----------|-------------|---------|
| `dev_users` | Lista de usuarios a configurar | ver arriba |
| `projects_dir` | Ruta de la carpeta compartida | `/projects` |
| `projects_group` | Grupo propietario del workspace | `projects` |
| `node_version` | Version de Node.js a instalar via FNM | `"lts"`, `"22"`, `"24"` |

## Ejecucion

Desde el directorio del proyecto, ejecuta el playbook con `sudo`:

```bash
cd /home/jalucenyo/dev-install
sudo ansible-playbook site.yml
```

Durante la ejecucion el playbook pedira:

- `PAT de GitHub (dejar vacio para omitir auth de gh):` — token personal de GitHub. Es opcional; si lo dejas vacio, `gh` se instalara pero no se autenticara.

> El PAT, si se introduce, se aplica a todos los usuarios configurados en `dev_users`.

## Qué instala

### Sistema (`tasks/system.yml`)

- Dependencias base: `git`, `curl`, `wget`, `unzip`, `zip`, `build-essential`, `acl`, `python3`, etc.
- Servidor SSH (`openssh-server`)
- Docker CE, Docker CLI, Buildx, Compose plugin
- VS Code
- GitHub CLI (`gh`)

### Usuarios (`tasks/users.yml`)

- Crea el grupo `projects`
- Asegura que existen `jalucenyo` y `agent`
- Asigna ambos usuarios a los grupos `projects` y `docker`
- Garantiza que `agent` no tiene privilegios de sudo

### Workspace (`tasks/workspace.yml`)

- Crea `/projects` con permisos `2775` y ACLs para ambos usuarios
- Monta bind mounts en `/home/jalucenyo/projects` y `/home/agent/projects`

### Por usuario

Cada uno de los siguientes componentes se instala de forma aislada en el home de cada usuario:

- **SSH:** clave ED25519 + `~/.ssh/config` para GitHub
- **Git:** `user.name`, `user.email`, `init.defaultBranch`, `pull.rebase`, `core.editor`
- **GitHub CLI:** autenticacion con PAT si se proporciona
- **Node.js:** FNM + version configurada en `node_version`
- **pnpm:** gestor de paquetes
- **Python:** uv
- **Agentes:** OpenCode y Claude Code
- **Portless:** proxy local para URLs `.localhost`

## Notas

- El playbook muestra las claves publicas SSH generadas para que puedas anadirlas a GitHub.
- OpenCode y Claude Code se instalan por usuario; la autenticacion con sus servicios se realiza despues de forma interactiva.
- Portless requiere Node.js 24+. El playbook instala Node 24 junto a la version LTS elegida para este componente.
- VS Code se instala globalmente para todos los usuarios.

## Solucion de problemas

### El playbook falla por sudo

Asegurate de ejecutar el playbook con `sudo`:

```bash
sudo ansible-playbook site.yml
```

Si tu usuario no tiene permisos de sudo, el playbook no podra ejecutarse.

### Docker no tiene repositorio para mi version de Ubuntu

Si el repositorio oficial de Docker aun no soporta tu version de Ubuntu, edita `tasks/system.yml` y cambia `{{ ansible_distribution_release }}` por el codename de la ultima LTS soportada (por ejemplo, `noble`).

### Quiero omitir un componente

Comenta o elimina la linea correspondiente en `site.yml`.

## Licencia

Uso interno. Personalizalo libremente.
