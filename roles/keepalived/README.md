# Ansible Role: Keepalived

## 📋 Descripción

El rol `keepalived` configura Keepalived para gestionar la IP virtual (VIP) del clúster PostgreSQL HA. Keepalived utiliza el protocolo VRRP (Virtual Router Redundancy Protocol) para proporcionar alta disponibilidad de la dirección IP, asegurando que siempre haya un nodo activo que responda en la VIP.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Instalación de Keepalived** desde los repositorios del sistema
2. **Configuración de sysctl** para permitir binding a IPs no locales
3. **Backup de configuración** original
4. **Configuración VRRP** con prioridades según rol
5. **Health checks de HAProxy** para determinar disponibilidad
6. **Gestión automática** de failover de IP virtual

## 📁 Estructura del Rol

```
roles/keepalived/
├── defaults/
│   └── main.yml            # Variables por defecto (vacío)
├── handlers/
│   └── main.yml            # Handler para sysctl
├── tasks/
│   └── main.yml            # Tareas principales
├── templates/
│   └── keepalived.conf.j2  # Template de configuración
├── vars/
│   └── main.yml            # Variables del rol (vacío)
└── README.md               # Este archivo
```

## 🏗️ Arquitectura VRRP

### Funcionamiento de la IP Virtual

```
Estado Normal:
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  server-node1   │         │  server-node2   │         │  server-node3   │
│  MASTER (101)   │         │  BACKUP (100)   │         │  BACKUP (100)   │
│  VIP: ✓         │         │  VIP: ✗         │         │  VIP: ✗         │
└────────┬────────┘         └─────────────────┘         └─────────────────┘
         │
         ▼
   192.168.20.81
   (IP Virtual)

Failover (server-node1 cae):
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  server-node1   │         │  server-node2   │         │  server-node3   │
│  FAULT          │         │  MASTER (100)   │         │  BACKUP (100)   │
│  VIP: ✗         │         │  VIP: ✓         │         │  VIP: ✗         │
└─────────────────┘         └────────┬────────┘         └─────────────────┘
                                     │
                                     ▼
                               192.168.20.81
                               (IP Virtual)
```

### Protocolo VRRP

```
┌─────────────────────────────────────────────────────┐
│                  Mensajes VRRP                      │
├─────────────────────────────────────────────────────┤
│  • Virtual Router ID: 51                            │
│  • Intervalo: 1 segundo                             │
│  • Prioridad: 101 (Master) / 100 (Backup)         │
│  • Autenticación: Ninguna (puede configurarse)     │
│  • Multicast: 224.0.0.18                          │
└─────────────────────────────────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    ▼                     ▼                     ▼
Nodo 1 (MASTER)      Nodo 2 (BACKUP)      Nodo 3 (BACKUP)
Envía anuncios       Escucha anuncios     Escucha anuncios
cada segundo         Toma control si       Toma control si
                     no hay anuncios       no hay anuncios
```

## 📊 Variables

### Variables Utilizadas

```yaml
# Desde inventory/hosts
patroni_role: "master" # Define si es MASTER o BACKUP
network_interface: "enp1s0" # Interfaz de red principal

# Desde group_vars/all/vars.yaml
virtual_ip: "192.168.20.81" # IP Virtual del clúster
```

### Configuración Generada

El template produce:

```bash
# Script de verificación de HAProxy
vrrp_script check_haproxy {
    script "pkill -0 haproxy"    # Verifica si HAProxy está corriendo
    interval 2                    # Cada 2 segundos
    weight 2                      # Peso del check
}

# Instancia VRRP
vrrp_instance VI_1 {
    state MASTER                  # o BACKUP según patroni_role
    interface enp1s0              # Interfaz de red
    virtual_router_id 51          # ID único del router virtual
    priority 101                  # 101 para MASTER, 100 para BACKUP
    advert_int 1                  # Intervalo de anuncios (segundos)

    virtual_ipaddress {
        192.168.20.81             # IP Virtual
    }

    track_script {
        check_haproxy             # Vincula con el health check
    }
}
```

## 🚀 Tareas Ejecutadas

### 1. Instalación de Keepalived

```bash
# Con DNF
dnf install -y keepalived

# Con YUM
yum install -y keepalived
```

### 2. Configuración de Kernel

Modifica `/etc/sysctl.conf`:

```bash
# Permite binding a IPs no locales
net.ipv4.ip_nonlocal_bind = 1

# Habilita IP forwarding
net.ipv4.ip_forward = 1
```

Aplica cambios:

```bash
sysctl --system
sysctl -p
```

### 3. Configuración de Keepalived

- Backup del archivo original
- Generación desde template con rol específico
- Asignación de prioridades según el rol

### 4. Inicio del Servicio

```bash
systemctl enable keepalived
systemctl start keepalived
```

## 🔍 Health Checks

### Script check_haproxy

```bash
vrrp_script check_haproxy {
    script "pkill -0 haproxy"    # Retorna 0 si HAProxy está corriendo
    interval 2                    # Verificar cada 2 segundos
    weight 2                      # Si falla, reduce prioridad en 2
}
```

### Flujo de Decisión

```
1. Keepalived ejecuta "pkill -0 haproxy"
2. Si HAProxy está corriendo → exit 0 → Mantiene prioridad
3. Si HAProxy no está → exit 1 → Reduce prioridad
4. Si prioridad < que otro nodo → Cede el rol MASTER
```

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Configurar Keepalived para VIP
  hosts: postgresql_servers
  become: true

  roles:
    - keepalived
```

### Con Tags

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags keepalived
```

### Verificación Post-Instalación

```bash
# Estado del servicio
systemctl status keepalived

# Ver logs
journalctl -u keepalived -f

# Verificar IP virtual (solo en MASTER)
ip addr show | grep 192.168.20.81

# Estado detallado
cat /var/run/keepalived.pid
```

## 🛠️ Comandos Útiles

### Verificar Estado VRRP

```bash
# Ver mensajes VRRP
tcpdump -i enp1s0 -nn vrrp

# Monitorear transiciones
journalctl -u keepalived | grep -E "(Entering|Transition)"

# Ver estadísticas de interfaz
ip -s link show enp1s0
```

### Forzar Cambio de Estado

```bash
# Detener keepalived en el MASTER actual
systemctl stop keepalived

# O reducir prioridad temporalmente
# Editar /etc/keepalived/keepalived.conf
# Cambiar priority a un valor menor
systemctl reload keepalived
```

### Script de Monitoreo

```bash
#!/bin/bash
# check_vip_status.sh

VIP="192.168.20.81"
INTERFACE="enp1s0"

echo "=== Estado de Keepalived ==="
systemctl is-active keepalived

echo -e "\n=== IP Virtual ==="
if ip addr show $INTERFACE | grep -q $VIP; then
    echo "VIP $VIP está ACTIVA en este nodo"
    echo "Estado: MASTER"
else
    echo "VIP $VIP NO está activa en este nodo"
    echo "Estado: BACKUP"
fi

echo -e "\n=== Últimas transiciones ==="
journalctl -u keepalived -n 20 | grep -E "(MASTER|BACKUP|FAULT)"
```

## ⚠️ Consideraciones Importantes

### Split-Brain Prevention

Para evitar split-brain (múltiples MASTER):

1. **Use prioridades diferentes** entre nodos
2. **Configure autenticación VRRP**:

```bash
authentication {
    auth_type PASS
    auth_pass SecurePassword123!
}
```

3. **Verifique conectividad multicast**:

```bash
# El firewall debe permitir multicast
firewall-cmd --direct --add-rule ipv4 filter INPUT 0 \
  -d 224.0.0.18 -j ACCEPT
```

### Configuración de Red

Requisitos de red:

- Multicast debe estar habilitado
- MTU consistente entre nodos
- Sin filtrado de paquetes VRRP (protocolo 112)

### Debugging Avanzado

```bash
# Ejecutar en modo debug
keepalived -f /etc/keepalived/keepalived.conf -D -l

# Ver dump de configuración
keepalived --dump-conf

# Verificar sintaxis
keepalived -t -f /etc/keepalived/keepalived.conf
```

## 🐛 Troubleshooting

### La VIP no aparece en ningún nodo

```bash
# Verificar que keepalived esté corriendo
systemctl status keepalived

# Verificar logs por errores
journalctl -u keepalived | tail -50

# Verificar interfaz de red
ip link show enp1s0

# Verificar multicast
ip maddr show enp1s0 | grep 224.0.0.18
```

### Múltiples nodos con la VIP (split-brain)

```bash
# Verificar en TODOS los nodos
for node in server-node1 server-node2 server-node3; do
    echo "=== $node ==="
    ssh $node "ip addr show | grep 192.168.20.81"
done

# Solución: Reiniciar keepalived en todos los nodos
# En orden: backups primero, master último
```

### VIP no failover cuando cae el master

```bash
# Verificar prioridades
grep priority /etc/keepalived/keepalived.conf

# Verificar script de check
pkill -0 haproxy; echo $?

# Ver comunicación VRRP
tcpdump -i enp1s0 -c 10 vrrp
```

### Flapping (cambios constantes de master)

Posibles causas:

- Problemas de red (pérdida de paquetes)
- Health check muy agresivo
- Prioridades iguales

Solución:

```bash
# Aumentar intervalo de anuncios
advert_int 2

# Aumentar intervalo de health check
interval 5

# Agregar delay en script
vrrp_script check_haproxy {
    script "/usr/local/bin/check_haproxy_with_delay.sh"
    interval 5
    fall 2    # Requiere 2 fallos consecutivos
    rise 2    # Requiere 2 éxitos consecutivos
}
```

## 🔐 Seguridad

### Autenticación VRRP

```bash
vrrp_instance VI_1 {
    # ... otras configuraciones ...

    authentication {
        auth_type PASS          # o AH para IPSEC-AH
        auth_pass MySecret123!  # Máximo 8 caracteres para PASS
    }
}
```

### Unicast en lugar de Multicast

Para entornos que no soportan multicast:

```bash
vrrp_instance VI_1 {
    # Deshabilitar multicast
    unicast_src_ip 192.168.20.80

    unicast_peer {
        192.168.20.82
        192.168.20.84
    }
}
```

### Restricciones de Interfaz

```bash
# Limitar VRRP a una VLAN específica
interface enp1s0.100    # VLAN 100
```

## 📊 Monitoreo

### Métricas Importantes

- Transiciones de estado (MASTER ↔ BACKUP)
- Tiempo en estado MASTER
- Pérdida de anuncios VRRP
- Estado del health check

### Integración con Prometheus

```yaml
# keepalived_exporter
- job_name: "keepalived"
  static_configs:
    - targets: ["localhost:9165"]
```

### Alertas Recomendadas

1. **Demasiadas transiciones** (> 3 en 5 minutos)
2. **Sin MASTER activo** en el clúster
3. **Múltiples MASTER** detectados
4. **Health check fallando** constantemente

## 🔗 Dependencias

### Prerequisitos

- `common` - Sistema configurado
- `firewall` - Puerto 112/tcp y protocolo VRRP permitidos
- `haproxy` - Debe estar instalado para health checks

### Dependientes

- Ninguno (último en la cadena)

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Probar en diferentes topologías de red
2. Documentar casos extremos (split-brain, etc.)
3. Mantener compatibilidad con IPv6
4. Incluir mejores prácticas de VRRP

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
