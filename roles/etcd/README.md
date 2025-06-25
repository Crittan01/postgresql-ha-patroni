# Ansible Role: etcd

## 📋 Descripción

El rol `etcd` instala y configura un clúster etcd distribuido que actúa como el almacén de configuración distribuido (DCS - Distributed Configuration Store) para Patroni. etcd es fundamental para mantener el consenso sobre el estado del clúster PostgreSQL y coordinar las operaciones de failover.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Configuración de repositorios** PostgreSQL y pgdg-extras
2. **Instalación de etcd** desde los repositorios oficiales
3. **Configuración del clúster etcd** con 3 nodos
4. **Inicialización y arranque** del servicio
5. **Configuración de variables de entorno** para facilitar la gestión
6. **Verificación del estado** del clúster etcd

## 📁 Estructura del Rol

```
roles/etcd/
├── defaults/
│   └── main.yml      # Variables por defecto (vacío)
├── handlers/
│   └── main.yml      # Handlers (vacío)
├── tasks/
│   └── main.yml      # Tareas principales
├── templates/
│   └── etcd.conf.j2  # Template de configuración etcd
├── vars/
│   └── main.yml      # Variables del rol (vacío)
└── README.md         # Este archivo
```

## 🔑 Conceptos Clave de etcd

### ¿Qué es etcd?

etcd es un almacén de clave-valor distribuido que proporciona:

- **Consenso distribuido** usando el algoritmo Raft
- **Alta disponibilidad** con replicación automática
- **Consistencia fuerte** para datos críticos
- **Watch API** para notificaciones de cambios

### Rol en el Clúster Patroni

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Patroni 1  │     │  Patroni 2  │     │  Patroni 3  │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                    ┌──────▼──────┐
                    │  etcd API   │
                    └──────┬──────┘
       ┌───────────────────┴───────────────────┐
       │                                       │
┌──────▼──────┐     ┌─────────────┐     ┌─────▼───────┐
│  etcd-node1 │◄────┤    Raft     ├────►│  etcd-node2 │
└──────┬──────┘     │  Consensus  │     └──────┬──────┘
       │            └──────┬──────┘             │
       │                   │                    │
       └───────────────────┴────────────────────┘
                           │
                    ┌──────▼──────┐
                    │  etcd-node3 │
                    └─────────────┘
```

## 📊 Variables

### Variables Requeridas del Inventario

```yaml
# Definidas en inventory/hosts
ansible_host: "192.168.20.80" # IP del host
inventory_hostname: "server-node1" # Nombre del host

# Lista de servidores (grupo)
groups['postgresql_servers']:
  - server-node1
  - server-node2
  - server-node3
```

### Variables Automáticas Utilizadas

```yaml
ansible_usr: "{{ ansible_user }}" # Usuario SSH
postgres_user: "postgres" # Usuario de PostgreSQL
```

### Configuración de etcd (template)

El template `etcd.conf.j2` genera:

```bash
# Nombre único del miembro
ETCD_NAME=server-node1

# Directorio de datos
ETCD_DATA_DIR="/var/lib/etcd/server-node1"

# URLs de escucha (peer y cliente)
ETCD_LISTEN_PEER_URLS="http://192.168.20.80:2380,http://127.0.0.1:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.20.80:2379,http://127.0.0.1:2379"

# URLs de anuncio
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.20.80:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.20.80:2379"

# Configuración del clúster
ETCD_INITIAL_CLUSTER="server-node1=http://192.168.20.80:2380,server-node2=http://192.168.20.82:2380,server-node3=http://192.168.20.84:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

# Habilitar API v2 (requerido por Patroni)
ETCD_ENABLE_V2="true"
```

## 🚀 Tareas Ejecutadas

### 1. Configuración de Repositorios

```bash
# Descargar e importar claves GPG
wget https://download.postgresql.org/pub/repos/yum/keys/PGDG-RPM-GPG-KEY-RHEL
rpm --import PGDG-RPM-GPG-KEY-RHEL

# Instalar repositorio PostgreSQL
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Habilitar repositorio pgdg-rhel8-extras
dnf config-manager --set-enabled pgdg-rhel8-extras
```

### 2. Instalación de etcd

```bash
# Instalar desde el repositorio pgdg-extras
dnf install -y etcd
```

### 3. Configuración del Clúster

- Backup del archivo original: `/etc/etcd/etcd.conf.orig`
- Generación del nuevo archivo desde template
- Configuración específica para cada nodo

### 4. Inicio del Servicio

```bash
systemctl enable etcd
systemctl start etcd
```

### 5. Variables de Entorno

Agrega a `.bash_profile` de usuarios:

```bash
# IPs de los nodos
export server-node1=192.168.20.80
export server-node2=192.168.20.82
export server-node3=192.168.20.84

# Endpoints del clúster
export ENDPOINTS=$server-node1:2379,$server-node2:2379,$server-node3:2379
```

### 6. Verificación del Estado

```bash
etcdctl endpoint status --write-out=table --endpoints="$ENDPOINTS"
```

## 🛠️ Comandos Útiles de etcd

### Estado del Clúster

```bash
# Ver estado de todos los endpoints
etcdctl endpoint status --write-out=table --endpoints="$ENDPOINTS"

# Ver salud del clúster
etcdctl endpoint health --endpoints="$ENDPOINTS"

# Ver miembros del clúster
etcdctl member list --endpoints="$ENDPOINTS"
```

### Gestión de Datos

```bash
# Listar todas las claves
etcdctl get "" --prefix --keys-only --endpoints="$ENDPOINTS"

# Ver configuración de Patroni
etcdctl get /db/postgres --prefix --endpoints="$ENDPOINTS"

# Ver el líder actual
etcdctl get /db/postgres/leader --endpoints="$ENDPOINTS"
```

### Mantenimiento

```bash
# Compactar el historial
etcdctl compact $(etcdctl endpoint status --write-out="json" | jq -r '.[] | .Status.header.revision')

# Desfragmentar
etcdctl defrag --endpoints="$ENDPOINTS"

# Backup
etcdctl snapshot save backup.db --endpoints="$ENDPOINTS"

# Restaurar
etcdctl snapshot restore backup.db \
  --name server-node1 \
  --initial-cluster server-node1=http://192.168.20.80:2380,server-node2=http://192.168.20.82:2380,server-node3=http://192.168.20.84:2380 \
  --initial-cluster-token etcd-cluster \
  --initial-advertise-peer-urls http://192.168.20.80:2380
```

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Configurar clúster etcd
  hosts: postgresql_servers
  become: true

  roles:
    - etcd
```

### Con Tags

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags etcd
```

### Verificación Post-Instalación

```bash
# En cualquier nodo
source ~/.bash_profile
etcdctl endpoint status --write-out=table --endpoints="$ENDPOINTS"
```

Salida esperada:

```
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|     ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 192.168.20.80:2379| 8e9e05c52164694d |  3.5.9  |  20 kB  |   true    |   false    |         2 |         10 |                 10 |        |
| 192.168.20.82:2379| 8e9e05c52164694e |  3.5.9  |  20 kB  |   false   |   false    |         2 |         10 |                 10 |        |
| 192.168.20.84:2379| 8e9e05c52164694f |  3.5.9  |  20 kB  |   false   |   false    |         2 |         10 |                 10 |        |
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

## ⚠️ Consideraciones Importantes

### Quórum y Tolerancia a Fallos

- Con 3 nodos: Tolera 1 fallo
- Con 5 nodos: Tolera 2 fallos
- **NUNCA** use un número par de nodos

### Seguridad

Para producción, considere:

1. **TLS/SSL** para comunicación cifrada:

```yaml
ETCD_CERT_FILE="/path/to/cert.pem"
ETCD_KEY_FILE="/path/to/key.pem"
ETCD_PEER_CERT_FILE="/path/to/peer-cert.pem"
ETCD_PEER_KEY_FILE="/path/to/peer-key.pem"
```

2. **Autenticación** de clientes:

```bash
etcdctl user add root
etcdctl auth enable
```

### Performance

- Use SSD para el directorio de datos
- Ajuste los parámetros de latencia:

```yaml
ETCD_HEARTBEAT_INTERVAL="100"
ETCD_ELECTION_TIMEOUT="1000"
```

## 🐛 Troubleshooting

### El servicio etcd no inicia

```bash
# Ver logs del servicio
journalctl -u etcd -f

# Verificar permisos del directorio
ls -la /var/lib/etcd/

# Verificar puerto en uso
ss -tlnp | grep 2379
```

### No se forma el clúster

```bash
# Verificar conectividad entre nodos
nc -zv server-node2 2380

# Verificar configuración
cat /etc/etcd/etcd.conf

# Limpiar y reiniciar (CUIDADO: pérdida de datos)
systemctl stop etcd
rm -rf /var/lib/etcd/*
systemctl start etcd
```

### Errores de "cluster ID mismatch"

```bash
# Detener todos los nodos
systemctl stop etcd

# Limpiar datos en TODOS los nodos
rm -rf /var/lib/etcd/*

# Reiniciar con estado "new"
# Asegurar ETCD_INITIAL_CLUSTER_STATE="new"
systemctl start etcd
```

### Pérdida de quórum

```bash
# Si perdió mayoría, forzar nuevo clúster
etcdctl snapshot save backup.db
# Luego restaurar como nuevo clúster
```

## 📊 Monitoreo

### Métricas Prometheus

etcd expone métricas en `http://localhost:2379/metrics`:

```yaml
# Ejemplo de configuración Prometheus
scrape_configs:
  - job_name: "etcd"
    static_configs:
      - targets:
          ["192.168.20.80:2379", "192.168.20.82:2379", "192.168.20.84:2379"]
```

### Alertas Recomendadas

- Pérdida de líder
- Latencia alta (>100ms)
- Espacio en disco bajo
- Número de peers < 3

## 🔗 Dependencias

### Prerequisitos

- `common` - Configuraciones básicas del SO
- `firewall` - Puertos 2379/2380 abiertos

### Dependientes

- `patroni` - Requiere etcd funcionando

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Pruebe cambios en entorno aislado
2. Verifique el impacto en el quórum
3. Documente cambios de configuración
4. Incluya procedimientos de rollback

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
