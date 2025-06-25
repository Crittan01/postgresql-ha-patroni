# Ansible Role: PostgreSQL

## 📋 Descripción

El rol `postgresql` instala PostgreSQL y sus componentes necesarios para el clúster de alta disponibilidad. Este rol **NO inicializa** la base de datos, ya que esa tarea es manejada por Patroni para garantizar la correcta configuración del clúster.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Deshabilita el módulo PostgreSQL nativo** del sistema operativo
2. **Habilita repositorios necesarios** según la distribución
3. **Instala PostgreSQL** con la versión especificada
4. **Crea la estructura de directorios** para los datos
5. **Prepara el entorno** para la inicialización por Patroni

## 📁 Estructura del Rol

```
roles/postgresql/
├── defaults/
│   └── main.yml      # Variables por defecto (vacío)
├── handlers/
│   └── main.yml      # Handlers (vacío)
├── tasks/
│   └── main.yml      # Tareas principales
├── vars/
│   └── main.yml      # Variables del rol (vacío)
└── README.md         # Este archivo
```

## 📊 Variables

### Variables Requeridas

Definidas en `group_vars/all/vars.yaml`:

```yaml
# Versión de PostgreSQL
postgres_version: "17" # Versión mayor de PostgreSQL

# Directorios
postgres_data_dir: "/u01/pgsql/17" # Directorio de datos
postgres_user: "postgres" # Usuario del sistema

# Variables de sistema (automáticas)
ansible_distribution: "OracleLinux" # Detectada automáticamente
ansible_distribution_major_version: "9" # Detectada automáticamente
ansible_pkg_mgr: "dnf" # dnf o yum
```

### Paquetes Instalados

```yaml
# Paquetes PostgreSQL instalados
- postgresql17-server # Servidor PostgreSQL
- postgresql17-contrib # Extensiones contrib
- postgresql17-devel # Archivos de desarrollo
```

## 🔄 Flujo de Instalación

### Diagrama del Proceso

```
┌─────────────────────────┐
│  Deshabilitar módulo    │
│  PostgreSQL nativo      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Habilitar repositorio  │
│  CodeReady/PowerTools   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Instalar PostgreSQL    │
│  desde PGDG repo        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Crear directorios      │
│  (NO inicializar DB)    │
└─────────────────────────┘
```

## 🚀 Tareas Ejecutadas

### 1. Deshabilitar Módulo PostgreSQL Nativo

```bash
# Evita conflictos con el PostgreSQL del sistema
dnf -qy module disable postgresql
```

⚠️ **Importante**: Esto es necesario en RHEL 8+ para evitar conflictos de versiones.

### 2. Habilitar Repositorios por Distribución

#### Para Rocky Linux:

```bash
dnf config-manager --set-enabled powertools
```

#### Para Oracle Linux:

```bash
# Con DNF
dnf config-manager --set-enabled ol9_codeready_builder

# Con YUM
yum-config-manager --enable ol9_codeready_builder
```

#### Para Red Hat Enterprise Linux:

```bash
# Requiere suscripción activa
subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms
```

### 3. Instalar PostgreSQL

```bash
# Instalación con DNF
dnf install -y postgresql17-server postgresql17-contrib postgresql17-devel

# Instalación con YUM
yum install -y postgresql17-server postgresql17-contrib postgresql17-devel
```

### 4. Crear Estructura de Directorios

```bash
# Crear directorio padre
mkdir -p /u01

# Asignar permisos
chown postgres:postgres /u01
chmod 744 /u01
```

## ⚠️ Notas Importantes

### NO Inicialización de Base de Datos

Este rol **NO ejecuta** `initdb` o `postgresql-setup`. Razones:

1. **Patroni gestiona la inicialización** del clúster
2. **Evita conflictos** con la configuración de replicación
3. **Garantiza consistencia** en el clúster

### Directorios de PostgreSQL

```bash
# Estructura creada
/u01/
└── pgsql/
    └── 17/          # Será creado por Patroni
        ├── base/
        ├── global/
        ├── pg_wal/
        └── ...
```

### Binarios de PostgreSQL

Ubicación estándar:

```bash
/usr/pgsql-17/
├── bin/            # Ejecutables (psql, pg_dump, etc.)
├── lib/            # Librerías
└── share/          # Archivos compartidos
```

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Instalar PostgreSQL para clúster HA
  hosts: postgresql_servers
  become: true

  roles:
    - postgresql
```

### Con Tags

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags postgresql
```

### Verificación Post-Instalación

```bash
# Verificar instalación
rpm -qa | grep postgresql17

# Verificar binarios
which psql
/usr/pgsql-17/bin/psql --version

# Verificar directorios
ls -la /u01/
```

## 🔧 Personalización

### Cambiar Versión de PostgreSQL

En `group_vars/all/vars.yaml`:

```yaml
# Para PostgreSQL 16
postgres_version: "16"
postgres_data_dir: "/u01/pgsql/16"
postgres_bin_dir: "/usr/pgsql-16/bin"

# Para PostgreSQL 15
postgres_version: "15"
postgres_data_dir: "/u01/pgsql/15"
postgres_bin_dir: "/usr/pgsql-15/bin"
```

### Cambiar Ubicación de Datos

```yaml
# Usar partición diferente
postgres_data_dir: "/data/postgresql/17"
# Asegurar que el directorio padre existe
# y tiene los permisos correctos
```

### Paquetes Adicionales

Para agregar extensiones:

```yaml
# En tasks/main.yml, agregar a la lista de instalación
- postgresql17-server
- postgresql17-contrib
- postgresql17-devel
- postgresql17-plpython3 # Python procedural language
- postgresql17-plperl # Perl procedural language
```

## 🐛 Troubleshooting

### Error: "No se puede deshabilitar el módulo postgresql"

```bash
# Verificar módulos disponibles
dnf module list | grep postgresql

# Si no existe el módulo, es seguro continuar
```

### Error: "No se encuentra el paquete postgresql17-server"

```bash
# Verificar que el repositorio PGDG esté instalado
rpm -qa | grep pgdg

# Reinstalar si es necesario
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
```

### Error: "Repositorio codeready no encontrado"

Para Oracle Linux:

```bash
# Verificar nombre correcto del repo
dnf repolist all | grep -i codeready

# El nombre varía por versión:
# - ol8_codeready_builder
# - ol9_codeready_builder
```

Para RHEL:

```bash
# Verificar suscripción
subscription-manager status

# Listar repos disponibles
subscription-manager repos --list | grep -i codeready
```

### Verificar Instalación

Script de verificación completo:

```bash
#!/bin/bash
echo "=== Verificación de PostgreSQL ==="
echo "Versión instalada:"
rpm -qa | grep postgresql17

echo -e "\nBinarios:"
ls -la /usr/pgsql-17/bin/

echo -e "\nDirectorios:"
ls -la /u01/

echo -e "\nUsuario postgres:"
id postgres

echo -e "\nVariables de entorno:"
sudo -u postgres env | grep -i pg
```

## 🔐 Seguridad

### Permisos de Directorios

```bash
# Directorio de datos (cuando sea creado por Patroni)
/u01/pgsql/17/: 700 (postgres:postgres)

# Logs
/var/log/postgresql/: 700 (postgres:postgres)
```

### SELinux (si está habilitado)

```bash
# Contexto para directorio de datos personalizado
semanage fcontext -a -t postgresql_db_t "/u01/pgsql/17(/.*)?"
restorecon -Rv /u01/pgsql/
```

## 🔗 Dependencias

### Prerequisitos

- `common` - Configuraciones básicas y usuario postgres
- `firewall` - Puerto 5432 abierto
- `etcd` - Repositorio PGDG configurado

### Dependientes

- `patroni` - Requiere PostgreSQL instalado

## 📊 Versiones Soportadas

| PostgreSQL | EOL      | Recomendación        |
| ---------- | -------- | -------------------- |
| 17         | Nov 2029 | ✅ Producción        |
| 16         | Nov 2028 | ✅ Producción        |
| 15         | Nov 2027 | ✅ Producción        |
| 14         | Nov 2026 | ⚠️ Planear migración |
| 13         | Nov 2025 | ❌ No recomendado    |

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Pruebe con diferentes versiones de PostgreSQL
2. Verifique compatibilidad con distribuciones
3. Mantenga la separación con Patroni
4. Documente cambios de rutas o paquetes

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
