# Ansible Role: Firewall

## 📋 Descripción

El rol `firewall` configura las reglas de firewall necesarias para el funcionamiento del clúster PostgreSQL HA con Patroni. Este rol asegura que todos los puertos y protocolos requeridos estén correctamente configurados en `firewalld` para permitir la comunicación entre los componentes del clúster.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Instalación de firewalld** (si no está presente)
2. **Habilitación y arranque** del servicio firewalld
3. **Apertura de puertos TCP** necesarios para todos los componentes
4. **Habilitación de servicios** predefinidos
5. **Configuración de reglas enriquecidas** para protocolos especiales (VRRP)

## 📁 Estructura del Rol

```
roles/firewall/
├── defaults/
│   └── main.yml      # Variables por defecto (vacío)
├── handlers/
│   └── main.yml      # Handlers (vacío)
├── tasks/
│   └── main.yml      # Tareas principales
├── vars/
│   └── main.yml      # Variables del rol
└── README.md         # Este archivo
```

## 📊 Variables

### Variables del Rol (vars/main.yml)

```yaml
# Puertos TCP a abrir
firewall_ports:
  - "5432/tcp" # PostgreSQL - Base de datos principal
  - "6432/tcp" # PgBouncer - Connection pooler (opcional)
  - "8008/tcp" # Patroni API - Health checks y gestión
  - "2379/tcp" # etcd cliente - Comunicación con clientes
  - "2380/tcp" # etcd servidor - Comunicación entre nodos etcd
  - "5000/tcp" # HAProxy primario - Conexiones al nodo master
  - "5001/tcp" # HAProxy réplicas - Conexiones a nodos replica
  - "7000/tcp" # HAProxy stats - Interfaz de estadísticas
  - "112/tcp" # Keepalived - Protocolo VRRP
  - "5405/tcp" # Keepalived - Comunicación multicast

# Servicios predefinidos a habilitar
firewall_service:
  - "http" # Servicio HTTP (puerto 80)

# Reglas enriquecidas
firewall_rich_rule:
  - 'rule protocol value="vrrp" accept' # Protocolo VRRP para Keepalived
```

## 🔥 Configuración de Puertos

### Mapa de Puertos por Componente

| Componente     | Puerto | Protocolo | Descripción                                |
| -------------- | ------ | --------- | ------------------------------------------ |
| **PostgreSQL** | 5432   | TCP       | Puerto principal de la base de datos       |
| **PgBouncer**  | 6432   | TCP       | Connection pooler (si se implementa)       |
| **Patroni**    | 8008   | TCP       | API REST para health checks y gestión      |
| **etcd**       | 2379   | TCP       | API cliente de etcd                        |
| **etcd**       | 2380   | TCP       | Comunicación peer-to-peer entre nodos etcd |
| **HAProxy**    | 5000   | TCP       | Endpoint para conexiones al nodo primario  |
| **HAProxy**    | 5001   | TCP       | Endpoint para conexiones a réplicas        |
| **HAProxy**    | 7000   | TCP       | Interfaz web de estadísticas               |
| **Keepalived** | 112    | TCP/VRRP  | Protocolo VRRP para failover de IP         |
| **Keepalived** | 5405   | TCP       | Comunicación multicast entre nodos         |
| **HTTP**       | 80     | TCP       | Servicio HTTP general                      |

### Diagrama de Comunicación

```
┌─────────────────────────────────────────────────────────────┐
│                        Clientes                              │
└─────────────┬───────────────────────┬───────────────────────┘
              │                       │
              ▼                       ▼
        VIP:5000 (W)            VIP:5001 (R)
              │                       │
┌─────────────┴───────────────────────┴───────────────────────┐
│                    HAProxy (:7000 stats)                    │
└─────────────┬───────────────────────┬───────────────────────┘
              │                       │
              ▼                       ▼
         PostgreSQL              PostgreSQL
          (:5432)                 (:5432)
              │                       │
              ▼                       ▼
         Patroni API             Patroni API
          (:8008)                 (:8008)
              │                       │
              └───────────┬───────────┘
                          ▼
                    etcd cluster
                 (:2379 / :2380)
```

## 🚀 Tareas Ejecutadas

### 1. Instalación de firewalld

```bash
# Para sistemas con DNF
dnf install -y firewalld

# Para sistemas con YUM
yum install -y firewalld
```

### 2. Habilitación del Servicio

```bash
systemctl enable firewalld
systemctl start firewalld
```

### 3. Configuración de Puertos

Para cada puerto en `firewall_ports`:

```bash
firewall-cmd --zone=public --add-port=5432/tcp --permanent
firewall-cmd --reload
```

### 4. Habilitación de Servicios

```bash
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload
```

### 5. Reglas Enriquecidas

```bash
firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent
firewall-cmd --reload
```

## 🔧 Handlers

Este rol no define handlers específicos. Todas las reglas se aplican inmediatamente usando la opción `immediate: true`.

## 🔗 Dependencias

### Roles Prerequisitos

- `common` - Debe ejecutarse antes para configuraciones básicas

### Roles Dependientes

Todos los demás roles dependen de que el firewall esté correctamente configurado:

- `etcd`
- `postgresql`
- `patroni`
- `haproxy`
- `keepalived`

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Configurar Firewall para PostgreSQL HA
  hosts: postgresql_servers
  become: true

  roles:
    - firewall
```

### Con Tags

```yaml
---
- name: Configurar solo el firewall
  hosts: postgresql_servers
  become: true

  tasks:
    - name: Aplicar configuración de firewall
      include_role:
        name: firewall
      tags: ["firewall"]
```

### Ejecutar solo este rol

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags firewall
```

## 🛠️ Personalización

### Agregar Puertos Adicionales

Para agregar puertos adicionales, edite `vars/main.yml`:

```yaml
firewall_ports:
  - "5432/tcp"
  - "6432/tcp"
  # Agregar nuevos puertos aquí
  - "9999/tcp" # Mi servicio personalizado
```

### Agregar Servicios

```yaml
firewall_service:
  - "http"
  - "https" # Agregar HTTPS
  - "ntp" # Agregar NTP
```

### Zonas Personalizadas

Para usar una zona diferente a `public`, modifique las tareas:

```yaml
- name: Abrir puertos en zona personalizada
  ansible.posix.firewalld:
    port: "{{ item }}"
    zone: trusted # Cambiar zona aquí
    permanent: true
    state: enabled
    immediate: true
```

## ⚠️ Consideraciones de Seguridad

### Mejores Prácticas

1. **Principio de menor privilegio**: Solo abra los puertos estrictamente necesarios
2. **Zonas apropiadas**: Use zonas más restrictivas en producción
3. **Source filtering**: Considere limitar el acceso por IP origen:

```yaml
- name: Limitar acceso a red específica
  ansible.posix.firewalld:
    rich_rule: 'rule family="ipv4" source address="192.168.20.0/24" port port="5432" protocol="tcp" accept'
    permanent: true
    state: enabled
```

### Auditoría

Para verificar las reglas aplicadas:

```bash
# Ver todas las reglas
firewall-cmd --list-all

# Ver puertos abiertos
firewall-cmd --list-ports

# Ver servicios habilitados
firewall-cmd --list-services

# Ver reglas enriquecidas
firewall-cmd --list-rich-rules
```

## 🐛 Troubleshooting

### El servicio firewalld no inicia

```bash
# Verificar el estado
systemctl status firewalld

# Ver logs
journalctl -u firewalld -f

# Verificar si hay conflictos con iptables
systemctl status iptables
```

### Los puertos no se abren correctamente

```bash
# Verificar que el puerto esté abierto
firewall-cmd --query-port=5432/tcp

# Recargar las reglas
firewall-cmd --reload

# Verificar la zona activa
firewall-cmd --get-active-zones
```

### Conectividad entre nodos

```bash
# Probar conectividad a PostgreSQL
telnet server-node2 5432

# Probar conectividad a etcd
curl http://server-node2:2379/version

# Verificar VRRP (desde otro nodo)
tcpdump -i eth0 vrrp
```

### Reglas no persisten después de reinicio

```bash
# Asegurar que las reglas sean permanentes
firewall-cmd --runtime-to-permanent

# Verificar configuración permanente
firewall-cmd --permanent --list-all
```

## 📊 Monitoreo

### Verificar tráfico bloqueado

```bash
# Ver paquetes rechazados
journalctl -u firewalld | grep -i reject

# Monitorear en tiempo real
tail -f /var/log/messages | grep -i firewall
```

### Estado del firewall

```bash
# Script de verificación
#!/bin/bash
echo "=== Estado de Firewalld ==="
firewall-cmd --state
echo -e "\n=== Zona Activa ==="
firewall-cmd --get-active-zones
echo -e "\n=== Puertos Abiertos ==="
firewall-cmd --list-ports
echo -e "\n=== Servicios Habilitados ==="
firewall-cmd --list-services
```

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Mantenga la lista de puertos documentada
2. Pruebe en todas las distribuciones soportadas
3. Considere las implicaciones de seguridad
4. Actualice este README con cualquier cambio

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
