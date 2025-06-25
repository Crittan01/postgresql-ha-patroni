# Ansible Role: Common

## 📋 Descripción

El rol `common` realiza las configuraciones básicas del sistema operativo necesarias para preparar los nodos del clúster PostgreSQL HA. Este rol establece la base fundamental sobre la cual se construirán los demás componentes del clúster.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Gestión de Suscripciones RHEL** (opcional - comentado por defecto)
2. **Configuración del Sistema**
   - Configuración de SELinux
   - Configuración de zona horaria (comentado)
3. **Actualización del Sistema**
   - Actualización de todos los paquetes
   - Instalación de repositorios EPEL
   - Configuración de repositorios PostgreSQL
4. **Gestión de Usuarios**
   - Creación del usuario postgres
   - Configuración de privilegios sudo
5. **Configuración de Red**
   - Actualización del archivo `/etc/hosts`

## 📁 Estructura del Rol

```
roles/common/
├── defaults/
│   └── main.yml      # Variables por defecto
├── handlers/
│   └── main.yml      # Handlers (vacío)
├── tasks/
│   └── main.yml      # Tareas principales
├── templates/
│   └── hosts.j2      # Template para /etc/hosts
├── vars/
│   └── main.yml      # Variables del rol (vacío)
└── README.md         # Este archivo
```

## 📊 Variables

### Variables Requeridas

Estas variables deben estar definidas en `group_vars/all/vars.yaml`:

```yaml
# Usuario del sistema
postgres_user: "postgres" # Usuario de PostgreSQL
postgres_password: "SecurePass123" # Contraseña del usuario postgres

# Configuración de SELinux
selinux_state: "disabled" # Estado de SELinux (disabled|enforcing|permissive)
selinux_policy: "targeted" # Política de SELinux

# Configuración de red
virtual_ip: "192.168.20.81" # IP Virtual del clúster
domain_name: "example.local" # Dominio DNS (opcional)

# Zona horaria (opcional - comentada por defecto)
timezone: "America/Bogota" # Zona horaria del sistema
```

### Variables del Inventario

Variables definidas en el archivo de inventario:

```yaml
ansible_host: "192.168.20.80" # IP del host
ansible_user: "ansible" # Usuario SSH
```

### Variables Automáticas de Ansible

El rol utiliza estos facts de Ansible:

- `ansible_distribution`: Distribución del SO (RedHat, OracleLinux, Rocky)
- `ansible_distribution_major_version`: Versión mayor del SO (8, 9)
- `ansible_pkg_mgr`: Gestor de paquetes (dnf, yum)
- `inventory_hostname`: Nombre del host en el inventario
- `groups['postgresql_servers']`: Lista de todos los servidores PostgreSQL

## 🚀 Tareas Ejecutadas

### 1. Configuración de Red Hat Subscription Manager (RHSM)

**Estado**: Comentado por defecto

```yaml
# Para habilitar, descomentar líneas 2-47 en tasks/main.yml
```

Si usa RHEL con suscripción:

- Solicita credenciales RHSM interactivamente
- Desuscribe y re-suscribe el sistema
- Habilita auto-attach para repositorios

### 2. Configuración del Sistema

#### SELinux

```bash
# Configura SELinux según la variable selinux_state
# Si cambia el estado, reinicia el servidor automáticamente
```

#### Zona Horaria (Comentado)

```bash
# Para habilitar, descomentar líneas relacionadas con timezone
```

### 3. Actualización del Sistema

```bash
# Actualiza todos los paquetes del sistema
dnf update -y  # o yum update -y

# Instala repositorios necesarios
- EPEL (Extra Packages for Enterprise Linux)
- Repositorio oficial de PostgreSQL
- Herramientas básicas (dnf-utils/yum-utils, python3-pip)
```

### 4. Gestión del Usuario PostgreSQL

```bash
# Crea el usuario postgres
useradd postgres

# Configura contraseña
echo "postgres:password" | chpasswd

# Configura sudo sin contraseña
echo "postgres ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/postgres
```

### 5. Configuración de /etc/hosts

Genera el archivo `/etc/hosts` con:

- Entradas localhost estándar
- Todos los nodos del clúster
- IP virtual (ha-vip)

Template resultante:

```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# ANSIBLE MANAGED - POSTGRESQL: PATRONI SERVERS
192.168.20.80 server-node1
192.168.20.82 server-node2
192.168.20.84 server-node3
192.168.20.81 ha-vip
# ANSIBLE MANAGED - POSTGRESQL: PATRONI SERVERS
```

## 🔧 Handlers

Este rol no define handlers específicos.

## 🔗 Dependencias

Este rol no tiene dependencias de otros roles, pero es prerequisito para:

- `firewall`
- `etcd`
- `postgresql`
- `patroni`
- `haproxy`
- `keepalived`

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Configuración Básica del Sistema
  hosts: postgresql_servers
  become: true

  roles:
    - common
```

### Con Tags

```yaml
---
- name: Aplicar configuraciones comunes
  hosts: postgresql_servers
  become: true

  tasks:
    - name: Ejecutar rol common
      include_role:
        name: common
      tags: ["common"]
```

### Ejecutar solo este rol

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags common
```

## ⚠️ Notas Importantes

### Red Hat Subscription Manager

Si está usando **Red Hat Enterprise Linux** con suscripción activa:

1. **Descomentar** el bloque RHSM (líneas 2-47) en `tasks/main.yml`
2. El playbook solicitará credenciales RHSM interactivamente
3. Asegúrese de tener una suscripción válida

### SELinux

- Por defecto se configura como `disabled`
- Si cambia a `enforcing`, asegúrese de configurar las políticas necesarias
- El servidor se reiniciará automáticamente si SELinux cambia de estado

### Repositorios

El rol configura automáticamente:

- EPEL para la versión correspondiente del SO
- Repositorio oficial de PostgreSQL
- GPG keys necesarias

### Compatibilidad

Probado en:

- Red Hat Enterprise Linux 8/9
- Oracle Linux 8/9
- Rocky Linux 8/9

## 🐛 Troubleshooting

### Error: "Failed to download metadata for repo 'pgdg-rhel8-extras'"

```bash
# Verificar que el repositorio esté habilitado
dnf repolist
```

### Error: "GPG key retrieval failed"

```bash
# Importar manualmente las claves
rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
rpm --import https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL
```

### Error: "User postgres already exists"

Este error es esperado si el usuario ya existe. El rol continuará normalmente.

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Asegúrese de probar en las distribuciones soportadas
2. Mantenga la compatibilidad con dnf y yum
3. Documente cualquier nueva variable
4. Actualice este README con cambios significativos

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
