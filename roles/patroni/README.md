# Ansible Role: Patroni

## 📋 Descripción

El rol `patroni` instala y configura Patroni, la herramienta de gestión de clústeres PostgreSQL de alta disponibilidad. Patroni automatiza la configuración de replicación, maneja failovers automáticos y mantiene la consistencia del clúster utilizando etcd como almacén de configuración distribuido.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Instalación de Patroni** y sus dependencias
2. **Configuración del clúster** con parámetros específicos por nodo
3. **Configuración de watchdog** para mayor confiabilidad
4. **Inicialización ordenada** del clúster (master primero)
5. **Configuración de autenticación** y replicación
6. **Arranque y habilitación** del servicio

## 📁 Estructura del Rol

```
roles/patroni/
├── defaults/
│   └── main.yml        # Variables por defecto (vacío)
├── handlers/
│   └── main.yml        # Handlers (vacío)
├── tasks/
│   └── main.yml        # Tareas principales
├── templates/
│   └── patroni.yml.j2  # Template de configuración
├── vars/
│   └── main.yml        # Variables del rol (vacío)
└── README.md           # Este archivo
```

## 🏗️ Arquitectura de Patroni

### Componentes del Clúster

```
┌─────────────────────────────────────────────────────────┐
│                    Aplicaciones                         │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │    HAProxy     │ ◄── Keepalived (VIP)
         └───────┬────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│Patroni 1│  │Patroni 2│  │Patroni 3│  ◄── REST API (:8008)
└────┬────┘  └────┬────┘  └────┬────┘
     │            │            │
     ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│PostgreSQL│ │PostgreSQL│ │PostgreSQL│  ◄── Replicación
│ Master  │  │ Replica │  │ Replica │      Streaming
└─────────┘  └─────────┘  └─────────┘
     │            │            │
     └────────────┼────────────┘
                  ▼
            ┌─────────┐
            │  etcd   │  ◄── Estado del clúster
            └─────────┘
```

### Flujo de Failover

```
1. Detección de fallo     : Patroni detecta master caído
2. Consenso en etcd       : Nodos acuerdan nuevo master
3. Promoción de réplica   : Réplica elegida se convierte en master
4. Reconfiguración        : Otras réplicas siguen al nuevo master
5. Actualización HAProxy  : Health checks detectan cambio
```

## 📊 Variables

### Variables Requeridas

```yaml
# Definidas en group_vars/all/vars.yaml
postgres_version: "17"
postgres_data_dir: "/u01/pgsql/17"
postgres_bin_dir: "/usr/pgsql-17/bin"
postgres_user: "postgres"

# Definidas en group_vars/all/vault.yml (encriptadas)
postgres_password: "StrongPostgresPass123!"
replication_password: "StrongReplicationPass123!"

# Definidas en inventory/hosts por nodo
patroni_role: "master" # o "replica"
priority: 100 # Prioridad para ser elegido master (mayor = preferido)
```

### Configuración del Template (patroni.yml.j2)

```yaml
# Identificación del clúster
scope: postgres # Nombre del clúster
namespace: /db/ # Namespace en etcd
name: server-node1 # Nombre único del nodo

# API REST de Patroni
restapi:
  listen: 192.168.20.80:8008
  connect_address: 192.168.20.80:8008

# Conexión a etcd
etcd3:
  hosts: 192.168.20.80:2379,192.168.20.82:2379,192.168.20.84:2379

# Configuración de bootstrap (primera inicialización)
bootstrap:
  dcs:
    ttl: 30 # Time to live del master
    loop_wait: 10 # Intervalo de chequeo
    retry_timeout: 10 # Timeout para retry
    maximum_lag_on_failover: 1MB # Lag máximo para failover
    postgresql:
      use_pg_rewind: true # Usar pg_rewind para sincronización

# PostgreSQL
postgresql:
  listen: 192.168.20.80:5432
  connect_address: 192.168.20.80:5432
  data_dir: /u01/pgsql/17
  bin_dir: /usr/pgsql-17/bin
# Watchdog (comentado por defecto)
# watchdog:
#     mode: "automatic"
#     device: /dev/watchdog
#     safety_margin: 5
```

## 🚀 Tareas Ejecutadas

### 1. Instalación de Patroni

```bash
# Instalar paquetes
dnf install -y patroni patroni-etcd watchdog
```

### 2. Crear Directorio de Configuración

```bash
mkdir -p /etc/patroni
chmod 755 /etc/patroni
```

### 3. Generar Configuración

El template genera configuración específica para cada nodo con:

- IPs correctas del nodo
- Configuración de pg_hba para replicación
- Credenciales de autenticación
- Parámetros de PostgreSQL

### 4. Configurar Watchdog

```bash
# Configurar dispositivo
echo "watchdog-device = /dev/watchdog" >> /etc/watchdog.conf

# Crear nodo de dispositivo
mknod /dev/watchdog c 10 130

# Cargar módulo softdog
modprobe softdog

# Asignar permisos
chown postgres:postgres /dev/watchdog
```

⚠️ **Nota**: Watchdog está comentado en el template por defecto

### 5. Inicialización Ordenada

```yaml
# 1. Iniciar master primero
- Solo en inventory_hostname == groups['postgresql_servers'][0]
- Con patroni_role == 'master'

# 2. Esperar 15 segundos

# 3. Iniciar réplicas
- Los demás nodos se unen al clúster
```

## 🛠️ Comandos de Patroni

### Estado del Clúster

```bash
# Ver estado general
patronictl -c /etc/patroni/patroni.yml list

# Salida esperada:
+ Cluster: postgres (7350184426948975095) -----+----+-----------+
| Member       | Host          | Role    | State   | TL | Lag in MB |
+--------------+---------------+---------+---------+----+-----------+
| server-node1 | 192.168.20.80 | Leader  | running |  1 |           |
| server-node2 | 192.168.20.82 | Replica | running |  1 |         0 |
| server-node3 | 192.168.20.84 | Replica | running |  1 |         0 |
+--------------+---------------+---------+---------+----+-----------+
```

### Operaciones Comunes

```bash
# Configuración del clúster
patronictl -c /etc/patroni/patroni.yml show-config

# Editar configuración
patronictl -c /etc/patroni/patroni.yml edit-config

# Reiniciar un nodo
patronictl -c /etc/patroni/patroni.yml restart postgres server-node1

# Reiniciar todo el clúster
patronictl -c /etc/patroni/patroni.yml restart postgres

# Pausar gestión automática
patronictl -c /etc/patroni/patroni.yml pause

# Reanudar gestión automática
patronictl -c /etc/patroni/patroni.yml resume
```

### Failover y Switchover

```bash
# Switchover planificado
patronictl -c /etc/patroni/patroni.yml switchover
# Seguir los prompts interactivos

# Switchover específico
patronictl -c /etc/patroni/patroni.yml switchover \
  --leader server-node1 \
  --candidate server-node2

# Failover manual (solo en emergencias)
patronictl -c /etc/patroni/patroni.yml failover
```

### Mantenimiento

```bash
# Promover réplica manualmente
patronictl -c /etc/patroni/patroni.yml promote server-node2

# Reinicializar réplica
patronictl -c /etc/patroni/patroni.yml reinit postgres server-node3

# Remover nodo del clúster
patronictl -c /etc/patroni/patroni.yml remove server-node3
```

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Configurar Patroni para PostgreSQL HA
  hosts: postgresql_servers
  become: true

  roles:
    - patroni
```

### Con Tags

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags patroni
```

### Verificación Post-Instalación

```bash
# Estado del servicio
systemctl status patroni

# Logs
journalctl -u patroni -f

# API REST
curl http://192.168.20.80:8008/

# Estado del master
curl http://192.168.20.80:8008/master

# Estado de réplica
curl http://192.168.20.80:8008/replica
```

## ⚙️ Configuración Avanzada

### Habilitar Watchdog

En `templates/patroni.yml.j2`, descomentar:

```yaml
watchdog:
  mode: automatic # automatic, required, o off
  device: /dev/watchdog
  safety_margin: 5 # Segundos antes del timeout
```

### Ajustar Parámetros de Failover

```yaml
bootstrap:
  dcs:
    ttl: 30 # Reducir para failover más rápido
    loop_wait: 10 # Frecuencia de chequeo
    retry_timeout: 10 # Timeout antes de considerar nodo muerto
    maximum_lag_on_failover: 10MB # Aumentar si hay mucho lag
    master_start_timeout: 300 # Timeout para iniciar master
    synchronous_mode: true # Habilitar replicación síncrona
    synchronous_mode_strict: false # Estricto o no
```

### Configurar Prioridades

En `inventory/hosts`:

```ini
[postgresql_servers]
server-node1 ansible_host=192.168.20.80 patroni_role=master priority=100
server-node2 ansible_host=192.168.20.82 patroni_role=replica priority=90
server-node3 ansible_host=192.168.20.84 patroni_role=replica priority=80
```

Mayor `priority` = mayor probabilidad de ser elegido master

## 🐛 Troubleshooting

### Patroni no inicia

```bash
# Verificar logs
journalctl -u patroni -n 100

# Verificar conectividad a etcd
curl http://192.168.20.80:2379/version
```

### No se forma el clúster

```bash
# Verificar que etcd esté funcionando
etcdctl endpoint status --endpoints=$ENDPOINTS

# Verificar datos en etcd
etcdctl get /db/postgres --prefix --endpoints=$ENDPOINTS

# Limpiar y reiniciar (CUIDADO: pérdida de datos)
systemctl stop patroni
rm -rf /u01/pgsql/17/*
etcdctl del /db/postgres --prefix
systemctl start patroni
```

### Réplica no se sincroniza

```bash
# Ver logs de PostgreSQL
tail -f /u01/pgsql/17/log/postgresql-*.log

# Verificar conectividad
psql -h server-node1 -U replicator -d postgres -c "SELECT 1"

# Reinicializar réplica
patronictl -c /etc/patroni/patroni.yml reinit postgres server-node2
```

### API REST no responde

```bash
# Verificar binding
ss -tlnp | grep 8008

# Probar localmente
curl -v http://localhost:8008/

# Verificar firewall
firewall-cmd --list-ports | grep 8008
```

## 🔐 Seguridad

### Autenticación API REST

Agregar a la configuración:

```yaml
restapi:
  listen: 192.168.20.80:8008
  connect_address: 192.168.20.80:8008
  authentication:
    username: patroni
    password: SecureAPIPassword123!
```

### SSL/TLS para Replicación

```yaml
postgresql:
  parameters:
    ssl: on
    ssl_cert_file: "/path/to/server.crt"
    ssl_key_file: "/path/to/server.key"
    ssl_ca_file: "/path/to/ca.crt"
```

### Encriptación de Contraseñas

Usar scram-sha-256 en lugar de md5:

```yaml
pg_hba:
  - host replication replicator 0.0.0.0/0 scram-sha-256
  - host all all 0.0.0.0/0 scram-sha-256
```

## 📊 Monitoreo

### Métricas Patroni

```bash
# Endpoint de métricas
curl http://192.168.20.80:8008/metrics

# Configurar Prometheus
scrape_configs:
  - job_name: 'patroni'
    static_configs:
      - targets: ['192.168.20.80:8008','192.168.20.82:8008','192.168.20.84:8008']
```

### Alertas Recomendadas

- Lag de replicación > 10MB
- Failovers frecuentes
- Nodos en estado "unknown"
- API REST no disponible

## 🔗 Dependencias

### Prerequisitos

- `common` - Usuario postgres creado
- `firewall` - Puertos necesarios abiertos
- `etcd` - Clúster etcd funcionando
- `postgresql` - PostgreSQL instalado

### Dependientes

- `haproxy` - Usa health checks de Patroni
- `validacion` - Verifica estado del clúster

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Probar cambios en entorno de desarrollo
2. Verificar compatibilidad con versiones de PostgreSQL
3. Documentar nuevos parámetros
4. Incluir casos de uso y ejemplos

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
