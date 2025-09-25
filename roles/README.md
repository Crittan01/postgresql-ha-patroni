# PostgreSQL High Availability with Patroni - Ansible Automation

## 📋 Descripción

Este proyecto de Ansible automatiza la instalación y configuración de un clúster PostgreSQL de alta disponibilidad utilizando Patroni, etcd, HAProxy y Keepalived. Proporciona una solución robusta para implementar PostgreSQL con failover automático, balanceo de carga e inicialización automática de bases de datos.

## 🏗️ Arquitectura

El clúster implementa los siguientes componentes en cada nodo:

- **PostgreSQL**: Base de datos relacional
- **Patroni**: Gestión de clúster y failover automático
- **etcd**: Almacén distribuido de configuración (DCS)
- **HAProxy**: Balanceador de carga con endpoints separados
- **Keepalived**: Gestión de IP virtual (VIP) para alta disponibilidad

### Topología de Red

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   rocky9node1   │     │   rocky9node2   │     │   rocky9node3   │
│  192.168.20.80  │     │  192.168.20.82  │     │  192.168.20.84  │
│   (Master)      │     │   (Replica)     │     │   (Replica)     │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                                 │
                         ┌───────┴────────┐
                         │   VIP: ha-vip  │
                         │ 192.168.20.81  │
                         └────────────────┘
```

### Inicialización Automática de Base de Datos

- Creación automática de base de datos con esquema personalizado
- Carga de estructura de tablas con relaciones complejas
- Importación de datos iniciales desde scripts SQL
- Validación automática de integridad referencial
- Reporte detallado post-inicialización

## 📋 Requisitos Previos

### Sistema Operativo

- Red Hat Enterprise Linux 8/9
- Oracle Linux 8/9
- Rocky Linux 8/9

### Recursos Mínimos por Nodo

- CPU: 2 cores
- RAM: 4 GB
- Disco: 20 GB
- Red: Conectividad entre todos los nodos

### Software Requerido

- Ansible 2.9+ en el nodo controlador
- Python 3.6+ en todos los nodos
- Acceso SSH con privilegios sudo

## 📁 Estructura del Proyecto

```
postgresql-ha-patroni/
├── ansible.cfg
├── inventory/
│   ├── hosts
│   └── group_vars/
│       └── all/
│           ├── vars.yaml      # Variables principales
│           └── vault.yml      # Contraseñas encriptadas
├── postgresql-ha.yml          # Playbook principal
└── roles/
    ├── common/               # Configuraciones básicas del SO
    ├── firewall/            # Reglas de firewall
    ├── etcd/                # Clúster etcd
    ├── postgresql/          # Instalación PostgreSQL
    ├── patroni/             # Configuración Patroni
    ├── haproxy/             # Balanceador de carga
    ├── keepalived/          # IP virtual
    ├── validacion/          # Verificación del clúster
    └── database_init/       # Inicialización de base de datos
        ├── files/           # Scripts SQL
        │   ├── 0_value_types.sql
        │   ├── 1_formalities_1.sql
        │   ├── 2_templates.sql
        │   └── 3_template_labels_1.sql
        └── tasks/
            ├── main.yml
            ├── check_leader.yml
            ├── create_database.yml
            ├── create_tables.yml
            ├── apply_constraints.yml
            ├── load_data.yml
            └── generate_report.yml
```

## ⚙️ Variables de Configuración

### 🔧 Variables Principales (inventory/group_vars/all/vars.yaml)

```yaml
# Configuración de Red - AJUSTAR SEGÚN SU INFRAESTRUCTURA
virtual_ip: "192.168.20.81" # IP Virtual del clúster
network_interface: "enp1s0" # Interfaz de red principal

# Configuración del Sistema
domain_name: "example.local" # Dominio DNS
timezone: "America/Bogota" # Zona horaria
selinux_state: "disabled" # Estado de SELinux
selinux_policy: "targeted" # Política de SELinux

# Usuario del Sistema
ansible_user: "ansible" # Usuario para ejecutar Ansible
postgres_user: "postgres" # Usuario de PostgreSQL

# Versión de PostgreSQL
postgres_version: "17" # Versión de PostgreSQL a instalar

# Directorios PostgreSQL
postgres_data_dir: "/u01/pgsql/17" # Directorio de datos
postgres_bin_dir: "/usr/pgsql-17/bin" # Directorio de binarios

# Configuración de Base de Datos (database_init)
db_name: "doc-mgr_template-mgr-db" # Nombre de la base de datos
db_schema: "mgrtigodb" # Schema principal
db_user: "admin_db_gestordoc" # Usuario de la aplicación
db_timezone: "America/Bogota" # Timezone de la base de datos

# Puertos de Firewall (modificar si es necesario)
firewall_ports:
  - "5432/tcp" # PostgreSQL
  - "6432/tcp" # PgBouncer (si se implementa)
  - "8008/tcp" # Patroni API
  - "2379/tcp" # etcd cliente
  - "2380/tcp" # etcd servidor
  - "5000/tcp" # HAProxy primario
  - "5001/tcp" # HAProxy réplicas
  - "7000/tcp" # HAProxy stats
```

### 🔐 Variables Sensibles (inventory/group_vars/all/vault.yml)

Crear y encriptar el archivo con:

```bash
ansible-vault create inventory/group_vars/all/vault.yml
```

Contenido:

```yaml
# Contraseñas - CAMBIAR POR VALORES SEGUROS
postgres_password: "StrongPostgresPassword123!"
replication_password: "StrongReplicationPassword123!"
patroni_api_password: "StrongPatroniAPIPassword123!"
db_password: "admin_db_1*" # Contraseña para el usuario de la aplicación
```

### 📝 Archivo de Inventario (inventory/hosts)

```ini
[postgresql_servers]
rocky9node1 ansible_host=192.168.20.80 node_id=1 patroni_role=master priority=100
rocky9node2 ansible_host=192.168.20.82 node_id=2 patroni_role=replica priority=50
rocky9node3 ansible_host=192.168.20.84 node_id=3 patroni_role=replica priority=50

[patroni_cluster:children]
postgresql_servers

[all:children]
patroni_cluster
```

## 🚀 Instalación

### 1. Clonar el Repositorio

```bash
git clone <repository-url>
cd postgresql-ha-patroni
```

### 2. Configurar Variables

**IMPORTANTE**: Ajustar las variables según su infraestructura

```bash
# Editar variables principales
vim inventory/group_vars/all/vars.yaml

# Crear y editar variables sensibles
ansible-vault create inventory/group_vars/all/vault.yml

# Editar inventario
vim inventory/hosts
```

### 3. Verificar Conectividad

```bash
ansible -i inventory/hosts all -m ping
```

### 4. Ejecutar el Playbook Completo

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --ask-vault-pass
```

### 5. Ejecutar Roles Específicos (usando tags)

```bash
# Solo configuración básica
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags common --ask-vault-pass

# Solo infraestructura (sin DB)
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags common,firewall,etcd,postgresql,patroni,haproxy,keepalived --ask-vault-pass

# Solo inicialización de base de datos
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags database_init --ask-vault-pass
```

## 🗄️ Estructura de Base de Datos

El rol `database_init` crea automáticamente la siguiente estructura:

### Tablas Creadas

1. **value_types** - Catálogo de tipos de valores

   - Campos: name, regex, description, author, creation_date, last_update
   - Datos precargados: ALPHANUMERIC, ALPHABETIC, NUMBER, BOOLEAN, DATE, IMAGE, CONTRACT, CASE

2. **document_types** - Tipos de documentos

   - Campos: name, description, author, lifecycle_status, retention, creation_date, last_update

3. **formalities** - Trámites

   - Campos: name, description, lifecycle_status, creation_date, last_update, author

4. **metadata** - Metadatos

   - Campos: name, document_type_name, min_cardinality, creation_date, last_update, metadata

5. **templates** - Plantillas

   - Campos: name, version, lifecycle_status, type, author, valid_for, creation_date, last_update, retention, description, file_content

6. **template_labels** - Etiquetas de plantillas
   - Campos: template_name, template_version, name, value_type, size, description, author, min_cardinality, creation_date, last_update, metadata

### Relaciones (Foreign Keys)

- metadata → document_types
- template_labels → templates
- template_labels → value_types

## ✅ Validación del Clúster

### 1. Verificar Estado de Patroni

```bash
patronictl -c /etc/patroni/patroni.yml list
```

Salida esperada:

```
+ Cluster: postgres (7350184426948975095) -----+----+-----------+
| Member      | Host          | Role    | State   | TL | Lag in MB |
+-------------+---------------+---------+---------+----+-----------+
| rocky9node1 | 192.168.20.80 | Leader  | running |  1 |           |
| rocky9node2 | 192.168.20.82 | Replica | running |  1 |         0 |
| rocky9node3 | 192.168.20.84 | Replica | running |  1 |         0 |
+-------------+---------------+---------+---------+----+-----------+
```

### 2. Verificar IP Virtual

```bash
# En el nodo master
ip addr show | grep 192.168.20.81
```

### 3. Probar Conexión a PostgreSQL

```bash
# Conexión al master (puerto 5000)
psql -h 192.168.20.81 -p 5000 -U postgres -d doc-mgr_template-mgr-db

# Conexión a réplicas (puerto 5001)
psql -h 192.168.20.81 -p 5001 -U postgres -d doc-mgr_template-mgr-db
```

### 4. Verificar HAProxy Stats

Abrir en navegador: `http://192.168.20.81:7000`

### 5. Verificar Base de Datos Inicializada

```bash
# Conectar como usuario de aplicación
psql -h 192.168.20.81 -p 5000 -U admin_db_gestordoc -d doc-mgr_template-mgr-db

# Verificar tablas
\dt mgrtigodb.*

# Verificar datos
SELECT count(*) FROM mgrtigodb.value_types;
SELECT count(*) FROM mgrtigodb.formalities;
SELECT count(*) FROM mgrtigodb.templates;
```

## 🔧 Operaciones Comunes

### Switchover Manual

```bash
patronictl -c /etc/patroni/patroni.yml switchover
```

### Reiniciar un Nodo

```bash
patronictl -c /etc/patroni/patroni.yml restart postgres rocky9node1
```

### Ver Configuración del Clúster

```bash
patronictl -c /etc/patroni/patroni.yml show-config
```

## 🐛 Troubleshooting

### Problemas Comunes

1. **Error de conectividad SSH**

   ```bash
   # Verificar SSH
   ssh-copy-id ansible@servidor
   ```

2. **Firewall bloqueando puertos**

   ```bash
   # Verificar puertos abiertos
   firewall-cmd --list-all
   ```

3. **etcd no sincroniza**

   ```bash
   # Verificar estado de etcd
   etcdctl endpoint status --endpoints=$ENDPOINTS
   ```

4. **Patroni no inicia**

   ```bash
   # Ver logs
   journalctl -u patroni -f
   ```

5. **Error en inicialización de DB**

   ```bash
   # Verificar logs de PostgreSQL
   tail -f /u01/pgsql/17/log/*.log

   # Verificar conexión desde líder
   psql -h localhost -U postgres -l
   ```

### Logs Importantes

- Patroni: `/var/log/messages` o `journalctl -u patroni`
- PostgreSQL: `/u01/pgsql/17/log/`
- HAProxy: `/var/log/haproxy.log`
- Keepalived: `journalctl -u keepalived`
- etcd: `journalctl -u etcd`

## 📊 Monitoreo

### Dashboard HAProxy

- URL: `http://<virtual_ip>:7000`
- Muestra estado de nodos PostgreSQL
- Estadísticas de conexiones

### Comandos Útiles de Monitoreo

```bash
# Estado del clúster
patronictl -c /etc/patroni/patroni.yml list

# Lag de replicación
psql -h <virtual_ip> -p 5000 -U postgres -c "SELECT * FROM pg_stat_replication;"

# Conexiones activas
psql -h <virtual_ip> -p 5000 -U postgres -c "SELECT * FROM pg_stat_activity;"

# Tamaño de bases de datos
psql -h <virtual_ip> -p 5000 -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"
```

## 📚 Referencias

- [Patroni Documentation](https://patroni.readthedocs.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [etcd Documentation](https://etcd.io/docs/)
- [HAProxy Documentation](http://www.haproxy.org/)
- [Ansible PostgreSQL Modules](https://docs.ansible.com/ansible/latest/collections/community/postgresql/)

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver archivo LICENSE para más detalles.

## 👥 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Cree una rama para su feature (`git checkout -b feature/AmazingFeature`)
3. Commit sus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abra un Pull Request

## Advertencias

- **Siempre** realizar pruebas en un entorno no productivo antes de implementar
- Asegurarse de tener backups antes de realizar cambios
- Las contraseñas en este README son ejemplos, usar contraseñas seguras en producción
- Revisar y ajustar los parámetros de PostgreSQL según sus necesidades
- La inicialización de base de datos solo se ejecuta en el nodo líder
- Los scripts SQL deben estar en UTF-8 para evitar problemas de codificación

## 🔄 Historial de Versiones

### Versión 1.1.0 (Septiembre 2025)

- Agregado rol `database_init` para inicialización automática de base de datos
- Implementada tabla `value_types` como catálogo maestro
- Mejorada gestión de foreign keys y constraints
- Agregado reporte automático post-inicialización
- Actualizada documentación con nuevas funcionalidades

### Versión 1.0.0 (Junio 2024)

- Versión inicial con clúster PostgreSQL HA
- Implementación de Patroni, etcd, HAProxy y Keepalived
- Soporte para RHEL/Rocky/Oracle Linux

---

**Autor**: cgarzont (IS NTTDATA Col)  
**Última actualización**: Septiembre 2025  
**Versión**: 1.1.0
