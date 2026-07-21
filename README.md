# Entorno de desarrollo con Ansible

Playbook para instalar y configurar un entorno de desarrollo completo en Ubuntu, preparado para dos usuarios: `jalucenyo` (administrador) y `agent` (sin privilegios de sudo).

## Instalacion rapida en una maquina nueva

El script `install.sh` puede descargarse y ejecutarse directamente con `curl`.

```bash
curl -fsSL https://raw.githubusercontent.com/jalucenyo/workspace-dev/main/install.sh | sudo bash
```

El script detectara Ubuntu, instalara Ansible si es necesario, descargara este repositorio y ejecutara el playbook.

Durante la ejecucion el playbook pedira:

- `PAT de GitHub (dejar vacio para omitir auth de gh):` — token personal de GitHub. Es opcional; si lo dejas vacio, `gh` se instalara pero no se autenticara.

Tambien puedes evitar el prompt exportando la variable de entorno:

```bash
export GITHUB_TOKEN=ghp_xxxxxxxx
sudo -E bash install.sh
```

## Estructura del proyecto

```
dev-install/
├── ansible.cfg
├── inventory/localhost.yml
├── group_vars/
│   └── all.yml              # variables publicas (usuarios, repos, config)
├── install.sh               # bootstrap de una linea
├── site.yml                 # playbook principal
└── tasks/
    ├── system.yml           # dependencias, Docker, SSH, VS Code:, GitHub CLI
    ├── users.yml            # usuarios y grupos
    ├── workspace.yml        # /projects compartido + bind mounts
    ├── ssh.yml              # claves SSH por usuario
    ├── git.yml              # git config por usuario
    ├── github_cli.yml       # autenticacion gh por usuario
    ├── node.yml             # FNM + Node.js por usuario
    ├── pnpm.yml             # pnpm por usuario
    ├── python.yml           # uv por usuario
    ├── agents.yml           # OpenCode y Claude Code por usuario
    ├── portless.yml         # Portless por usuario
    ├── antigravity.yml      # Antigravity CLI por usuario
    └── openspec.yml         # OpenSpec por usuario
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
    sudo: true
  - name: agent
    git_name: "Agent"
    git_email: "agent@localhost"
    sudo: false

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
| `git_global_config` | Opciones globales de Git aplicadas a todos los usuarios | `init.defaultBranch`, `core.editor`, etc. |
| `apt_external_repos` | Lista de repositorios externos clave+repo+paquetes | Docker, VS Code:, gh |

## Ejecucion

Desde el directorio del proyecto, ejecuta el playbook con `sudo`:

```bash
cd /home/jalucenyo/dev-install
sudo ansible-playbook site.yml
```

Durante la ejecucion el playbook pedira:

- `PAT de GitHub (dejar vacio para omitir auth de gh):` — token personal de GitHub. Es opcional; si lo dejas vacio, `gh` se instalara pero no se autenticara.

> El PAT, si se introduce, se aplica a todos los usuarios configurados en `dev_users`.

### Ejecutar solo ciertos componentes

Cada componente del playbook tiene etiquetas (`tags`). Puedes ejecutar solo los que necesites o saltar otros:

```bash
# Solo Node.js y herramientas relacionadas
sudo ansible-playbook site.yml --tags node

# Todo excepto Docker y VS Code:
sudo ansible-playbook site.yml --skip-tags docker,vscode

# Solo agentes de codigo
sudo ansible-playbook site.yml --tags agents
```

Etiquetas disponibles:

`system`, `users`, `workspace`, `ssh`, `git`, `github`, `github_cli`, `node`, `pnpm`, `python`, `agents`, `portless`, `antigravity`, `openspec`, `docker`, `vscode`.

## Que instala

### Sistema (`tasks/system.yml`)

- Dependencias base: `git`, `curl`, `wget`, `unzip`, `zip`, `build-essential`, `acl`, `python3`, etc.
- Servidor SSH (`openssh-server`)
- Docker CE, Docker CLI, Buildx, Compose plugin
- VS Code:
- GitHub CLI (`gh`)

### Usuarios (`tasks/users.yml`)

- Crea el grupo `projects`
- Asegura que existen los usuarios definidos en `dev_users`
- Asigna ambos usuarios a los grupos `projects` y `docker`
- Garantiza que los usuarios con `sudo: false` no tienen entrada en `/etc/sudoers.d`

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
- **Antigravity CLI:** herramienta de Google
- **OpenSpec:** herramienta de Fission AI

## Anadir una nueva herramienta por usuario

Para mantener la consistencia, sigue el patron estandar de cualquiera de los archivos `tasks/*.yml`:

1. Crea un archivo `tasks/nueva_herramienta.yml`.
2. Usa `become_user: "{{ item.name }}"` y un loop sobre `dev_users`.
3. Aprovecha `node_env_preamble` si la herramienta necesita Node.js.
4. Preferiblemente usa `args.creates` con la ruta del binario conocido para idempotencia.
5. Si la ruta no es conocida, usa `command -v` + `when: item.rc != 0`.
6. Verifica con `--version` (o equivalente) y muestra el resultado con `debug`.
7. Importa el archivo en `site.yml` y asignale un `tag`.

Ejemplo minimo con binario conocido:

```yaml
---
- name: Instalar nueva herramienta
  become_user: "{{ item.name }}"
  ansible.builtin.shell:
    cmd: |
      curl -fsSL https://ejemplo.com/install | bash
  args:
    creates: "~{{ item.name }}/.local/bin/nueva-herramienta"
    executable: /bin/bash
  loop: "{{ dev_users }}"

- name: Verificar nueva herramienta
  become_user: "{{ item.name }}"
  ansible.builtin.shell:
    cmd: nueva-herramienta --version
  args:
    executable: /bin/bash
  register: nueva_version
  changed_when: false
  failed_when: false
  loop: "{{ dev_users }}"

- name: Mostrar version
  ansible.builtin.debug:
    msg: "nueva-herramienta de {{ item.item.name }}: {{ item.stdout | default('no disponible') }}"
  loop: "{{ nueva_version.results }}"
```

## Validacion local

Antes de ejecutar el playbook en una maquina real, revisa la sintaxis:

```bash
ansible-playbook site.yml --syntax-check
```

Si tienes `ansible-lint` instalado:

```bash
ansible-lint
```

## Notas

- El playbook muestra las claves publicas SSH generadas para que puedas anadirlas a GitHub.
- OpenCode y Claude Code se instalan por usuario; la autenticacion con sus servicios se realiza despues de forma interactiva.
- Portless requiere Node.js 24+. El playbook instala Node 24 junto a la version LTS elegida para este componente.
- VS Code: se instala globalmente para todos los usuarios.

## Solucion de problemas

### El playbook falla por sudo

Asegurate de ejecutar el playbook con `sudo`:

```bash
sudo ansible-playbook site.yml
```

Si tu usuario no tiene permisos de sudo, el playbook no podra ejecutarse.

### Docker no tiene repositorio para mi version de Ubuntu

Si el repositorio oficial de Docker aun no soporta tu version de Ubuntu, edita `group_vars/all.yml` y en `apt_external_repos` cambia `{{ ansible_distribution_release }}` por el codename de la ultima LTS soportada (por ejemplo, `noble`).

### Quiero omitir un componente

Usa `--skip-tags <etiqueta>` en lugar de editar `site.yml`. Por ejemplo:

```bash
sudo ansible-playbook site.yml --skip-tags docker
```

## Licencia

Uso interno. Personalalo libremente.
