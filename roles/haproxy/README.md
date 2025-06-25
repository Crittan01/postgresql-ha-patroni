# Ansible Role: HAProxy

## 📋 Descripción

El rol `haproxy` instala y configura HAProxy como balanceador de carga para el clúster PostgreSQL HA. HAProxy proporciona endpoints separados para conexiones de escritura (master) y lectura (réplicas), detectando automáticamente el estado de cada nodo mediante health checks contra la API de Patroni.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Instalación de HAProxy** desde los repositorios del sistema
2. **Backup de configuración** original
3. **Configuración de backends** separados para master y réplicas
4. **Health checks inteligentes** usando la API de Patroni
5. **Interfaz de estadísticas** para monitoreo
6. **Integración con Keepalived** mediante IP virtual

## 📁 Estructura del Rol

```
roles/haproxy/
├── defaults/
│   └── main.yml         # Variables por defecto (vacío)
├── handlers/
│   └── main.yml         # Handlers (vacío)
├── tasks/
│   └── main.yml         # Tareas principales
├── templates/
│   └── haproxy.cfg.j2   # Template de configuración
├── vars/
│   └── main.yml         # Variables del rol (vacío)
└── README.md            # Este archivo
```

## 🏗️ Arquitectura de Balanceo

### Flujo de Conexiones

```
                    Aplicaciones
                         │
                         ▼
                 ┌───────────────┐
                 │  VIP (ha-vip) │
                 │ 192.168.20.81 │ ◄── Keepalived
                 └───────┬───────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
    Puerto :5000                    Puerto :5001
    (Escritura)                      (Lectura)
         │                               │
         ▼                               ▼
   ┌─────────────┐                ┌─────────────┐
   │   Backend   │                │   Backend   │
   │   Primary   │                │   Standby   │
   └─────┬───────┘                └─────┬───────┘
         │                               │
         ▼                               ▼
   Health Check:                   Health Check:
   /master → 200                   /replica → 200
         │                               │
    ┌────┴────┐                    ┌────┴────┐
    │ Patroni │                    │ Patroni │
    │  :8008  │                    │  :8008  │
    └────┬────┘                    └────┬────┘
         │                               │
         ▼                               ▼
   ┌──────────┐                  ┌──────────┐
   │PostgreSQL│                  │PostgreSQL│
   │  Master  │                  │ Replica  │
   └──────────┘                  └──────────┘
```

### Endpoints Disponibles

| Endpoint | Puerto | Descripción     | Uso                                              |
| -------- | ------ | --------------- | ------------------------------------------------ |
| VIP:5000 | 5000   | Backend Primary | Conexiones de escritura (INSERT, UPDATE, DELETE) |
| VIP:5001 | 5001   | Backend Standby | Conexiones de solo lectura (SELECT)              |
| VIP:7000 | 7000   | Stats Interface | Interfaz web de estadísticas                     |

## 📊 Variables

### Variables Utilizadas

```yaml
# IP Virtual (desde group_vars)
virtual_ip: "192.168.20.81"

# Nodos del clúster (desde inventory)
groups['postgresql_servers']:
  - server-node1 (192.168.20.80)
  - server-node2 (192.168.20.82)
  - server-node3 (192.168.20.84)
```

### Configuración Generada

El template produce la siguiente estructura:

```
global
    maxconn 1000              # Conexiones máximas globales

defaults
    mode tcp                  # Modo TCP para PostgreSQL
    log global
    option tcplog
    retries 3
    timeout queue 1m          # Timeout en cola
    timeout connect 4s        # Timeout de conexión
    timeout client 60m        # Timeout del cliente
    timeout server 60m        # Timeout del servidor
    timeout check 5s          # Timeout de health check
    maxconn 900              # Conexiones por defecto

listen stats                  # Interfaz de estadísticas
    mode http
    bind *:7000
    stats enable
    stats uri /

listen primary               # Backend para escrituras
    bind 192.168.20.81:5000
    option httpchk OPTIONS /master
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server server-node1 192.168.20.80:5432 maxconn 100 check port 8008
    server server-node2 192.168.20.82:5432 maxconn 100 check port 8008
    server server-node3 192.168.20.84:5432 maxconn 100 check port 8008

listen standby               # Backend para lecturas
    bind 192.168.20.81:5001
    balance roundrobin
    option httpchk OPTIONS /replica
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server server-node1 192.168.20.80:5432 maxconn 100 check port 8008
    server server-node2 192.168.20.82:5432 maxconn 100 check port 8008
    server server-node3 192.168.20.84:5432 maxconn 100 check port 8008
```

## 🚀 Tareas Ejecutadas

### 1. Instalación de HAProxy

```bash
# Con DNF
dnf install -y haproxy

# Con YUM
yum install -y haproxy
```

### 2. Backup de Configuración

```bash
# Preserva permisos y ownership
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig
```

### 3. Aplicar Nueva Configuración

- Genera configuración desde template
- Mantiene permisos originales del archivo
- Incluye todos los nodos del inventario

### 4. Iniciar y Habilitar Servicio

```bash
systemctl enable haproxy
systemctl start haproxy
```

## 🔍 Health Checks Inteligentes

### Cómo Funcionan

HAProxy consulta la API REST de Patroni para determinar el rol de cada nodo:

```bash
# Check para master
curl -I http://192.168.20.80:8008/master
# Retorna 200 si es master, 503 si no

# Check para replica
curl -I http://192.168.20.80:8008/replica
# Retorna 200 si es replica (o master), 503 si no está disponible
```

### Parámetros de Health Check

```
inter 3s    # Intervalo entre checks (3 segundos)
fall 3      # Checks fallidos antes de marcar como down
rise 2      # Checks exitosos antes de marcar como up
on-marked-down shutdown-sessions  # Cerrar sesiones al caer
```

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Configurar HAProxy para PostgreSQL HA
  hosts: postgresql_servers
  become: true

  roles:
    - haproxy
```

### Con Tags

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags haproxy
```

### Verificación Post-Instalación

```bash
# Estado del servicio
systemctl status haproxy

# Verificar binding de puertos
ss -tlnp | grep -E '(5000|5001|7000)'

# Ver logs
journalctl -u haproxy -f

# Acceder a estadísticas
curl http://192.168.20.81:7000/
# O en navegador: http://192.168.20.81:7000/
```

## 🖥️ Interfaz de Estadísticas

### Acceso Web

Navegar a: `http://192.168.20.81:7000/`

### Información Disponible

- Estado de cada servidor (UP/DOWN)
- Número de conexiones activas
- Bytes transferidos
- Tasas de error
- Tiempos de respuesta
- Health check status

### Interpretación de Estados

| Color       | Estado | Significado                         |
| ----------- | ------ | ----------------------------------- |
| 🟢 Verde    | UP     | Nodo activo y pasando health checks |
| 🔴 Rojo     | DOWN   | Nodo caído o fallando health checks |
| 🟡 Amarillo | DRAIN  | Nodo en mantenimiento               |
| 🔵 Azul     | NOLB   | No balanceando (solo backup)        |

## 🛠️ Configuración Avanzada

### Ajustar Algoritmo de Balanceo

Para el backend de réplicas, cambiar algoritmo:

```
listen standby
    balance roundrobin    # Por defecto
    # Alternativas:
    # balance leastconn   # Menos conexiones
    # balance source      # Por IP origen
    # balance first       # Primer servidor disponible
```

### Configurar Logging Detallado

Agregar en la sección global:

```
global
    log 127.0.0.1:514 local0
    log 127.0.0.1:514 local1 notice
```

### Limitar Conexiones por Cliente

```
listen primary
    stick-table type ip size 100k expire 30s store conn_cur
    tcp-request connection reject if { src_conn_cur ge 10 }
```

### Habilitar Compresión (para pgbouncer)

Si se usa pgbouncer con protocolo HTTP:

```
defaults
    compression algo gzip
    compression type text/html text/plain
```

## 🐛 Troubleshooting

### HAProxy no inicia

```bash
# Verificar sintaxis
haproxy -f /etc/haproxy/haproxy.cfg -c

# Ver errores específicos
journalctl -xe -u haproxy

# Verificar permisos
ls -la /etc/haproxy/haproxy.cfg
```

### Todos los servidores aparecen DOWN

```bash
# Verificar conectividad a Patroni
curl http://192.168.20.80:8008/master

# Verificar firewall
firewall-cmd --list-ports | grep -E '(8008|5432)'

# Test manual de health check
curl -v http://192.168.20.80:8008/master
```

### No se puede conectar a PostgreSQL

```bash
# Verificar que HAProxy escucha en los puertos
netstat -tlnp | grep haproxy

# Probar conexión directa
psql -h 192.168.20.81 -p 5000 -U postgres

# Verificar logs de conexión
tail -f /var/log/haproxy.log
```

### Alto uso de CPU

```bash
# Ver estadísticas en tiempo real
echo "show stat" | socat /var/run/haproxy.sock stdio

# Verificar número de conexiones
echo "show sess" | socat /var/run/haproxy.sock stdio | wc -l
```

## 🔐 Seguridad

### Restringir Acceso a Estadísticas

```
listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /stats
    stats realm HAProxy\ Statistics
    stats auth admin:SecurePassword123!
    stats admin if TRUE
```

### Limitar Acceso por IP

```
listen primary
    bind 192.168.20.81:5000
    acl allowed_networks src 192.168.20.0/24 10.0.0.0/8
    tcp-request connection reject if !allowed_networks
```

### SSL/TLS Termination

Para conexiones SSL (requiere certificados):

```
listen primary_ssl
    bind 192.168.20.81:5433 ssl crt /etc/haproxy/certs/postgresql.pem
    mode tcp
    server server-node1 192.168.20.80:5432 check port 8008
```

## 📊 Monitoreo

### Métricas para Prometheus

Instalar haproxy_exporter:

```bash
# Configurar exporter
haproxy_exporter --haproxy.scrape-uri="http://192.168.20.81:7000/stats;csv"
```

### Alertas Recomendadas

- Servidor backend DOWN > 1 minuto
- Tasa de error > 1%
- Tiempo de respuesta > 100ms
- Conexiones activas > 80% del límite
- Queue depth > 0

## 🔗 Dependencias

### Prerequisitos

- `common` - Sistema configurado
- `firewall` - Puertos 5000, 5001, 7000 abiertos
- `patroni` - API REST disponible en puerto 8008

### Dependientes

- `keepalived` - Monitorea HAProxy para gestionar VIP

## 📈 Optimización de Performance

### Kernel Tuning

Agregar a `/etc/sysctl.conf`:

```bash
# Aumentar límites de conexión
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096

# Reutilización de sockets
net.ipv4.tcp_tw_reuse = 1

# Buffers de red
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
```

### Configuración de Conexiones

```
global
    maxconn 10000           # Aumentar para alta carga
    nbproc 4                # Múltiples procesos
    cpu-map 1 0             # Afinidad de CPU
    cpu-map 2 1
```

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Probar configuraciones en diferentes cargas
2. Documentar casos de uso específicos
3. Mantener compatibilidad con versiones de HAProxy
4. Incluir benchmarks de performance

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
