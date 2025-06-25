# PostgreSQL High Availability with Patroni - Ansible Automation

## 📋 Descripción

Este proyecto de Ansible automatiza la instalación y configuración de un clúster PostgreSQL de alta disponibilidad utilizando Patroni, etcd, HAProxy y Keepalived. Proporciona una solución robusta para implementar PostgreSQL con failover automático y balanceo de carga.

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
│   server-node1  │     │   server-node2  │     │   server-node3  │
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
    └── validacion/          # Verificación del clúster
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

# Prioridades para Patroni (ajustar según preferencia de nodos)
# server-node1
priority: 100 # Mayor valor = mayor prioridad para ser master

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
```

### 📝 Archivo de Inventario (inventory/hosts)

```ini
[postgresql_servers]
server-node1 ansible_host=192.168.20.80 patroni_role=master
server-node2 ansible_host=192.168.20.82 patroni_role=replica
server-node3 ansible_host=192.168.20.84 patroni_role=replica

[postgresql_servers:vars]
ansible_user=ansible
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## 🚀 Instalación

### 1. Clonar el Repositorio

```bash
git clone <repository-url>
cd postgresql-ha-patroni
```

### 2. Configurar Variables

⚠️ **IMPORTANTE**: Ajustar las variables según su infraestructura

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
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags common

# Solo PostgreSQL y Patroni
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags postgresql,patroni
```

## 🔴 Nota Importante: Red Hat Subscription Manager (RHSM)

Si está utilizando **Red Hat Enterprise Linux** con suscripción, debe **descomentar** el bloque RHSM en el archivo `roles/common/tasks/main.yml`:

```yaml
# Descomentar las líneas 2-47 del archivo roles/common/tasks/main.yml
# Este bloque solicitará las credenciales RHSM durante la ejecución
```

## ✅ Validación del Clúster

### 1. Verificar Estado de Patroni

```bash
patronictl -c /etc/patroni/patroni.yml list
```

Salida esperada:

```
+ Cluster: postgres (7350184426948975095) -----+----+-----------+
| Member       | Host          | Role    | State   | TL | Lag in MB |
+--------------+---------------+---------+---------+----+-----------+
| server-node1 | 192.168.20.80 | Leader  | running |  1 |           |
| server-node2 | 192.168.20.82 | Replica | running |  1 |         0 |
| server-node3 | 192.168.20.84 | Replica | running |  1 |         0 |
+--------------+---------------+---------+---------+----+-----------+
```

### 2. Verificar IP Virtual

```bash
# En el nodo master
ip addr show | grep 192.168.20.81
```

### 3. Probar Conexión a PostgreSQL

```bash
# Conexión al master (puerto 5000)
psql -h 192.168.20.81 -p 5000 -U postgres

# Conexión a réplicas (puerto 5001)
psql -h 192.168.20.81 -p 5001 -U postgres
```

### 4. Verificar HAProxy Stats

Abrir en navegador: `http://192.168.20.81:7000`

## 🔧 Operaciones Comunes

### Switchover Manual

```bash
patronictl -c /etc/patroni/patroni.yml switchover
```

### Reiniciar un Nodo

```bash
patronictl -c /etc/patroni/patroni.yml restart postgres server-node1
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
   ssh-copy-id usuario@servidor
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

### Logs Importantes

- Patroni: `/var/log/messages` o `journalctl -u patroni`
- PostgreSQL: `/u01/pgsql/17/log/`
- HAProxy: `/var/log/haproxy.log`
- Keepalived: `journalctl -u keepalived`

## 📚 Referencias

- [Patroni Documentation](https://patroni.readthedocs.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [etcd Documentation](https://etcd.io/docs/)
- [HAProxy Documentation](http://www.haproxy.org/)

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver archivo LICENSE para más detalles.

## 👥 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Cree una rama para su feature (`git checkout -b feature/AmazingFeature`)
3. Commit sus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abra un Pull Request

## ⚠️ Advertencias

- **Siempre** realizar pruebas en un entorno no productivo antes de implementar
- Asegurarse de tener backups antes de realizar cambios
- Las contraseñas en este README son ejemplos, usar contraseñas seguras en producción
- Revisar y ajustar los parámetros de PostgreSQL según sus necesidades

---

**Última actualización**: Junio 2025  
**Versión**: 1.0.0
