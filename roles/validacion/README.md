# Ansible Role: Validación

## 📋 Descripción

El rol `validacion` verifica que el clúster PostgreSQL HA con Patroni esté correctamente configurado y funcionando. Este rol ejecuta una serie de validaciones para confirmar que todos los componentes están operativos y el clúster está listo para producción.

## 🎯 Funcionalidades

Este rol ejecuta las siguientes tareas:

1. **Pausa inicial** para permitir estabilización del clúster
2. **Verificación del estado de Patroni** usando patronictl
3. **Visualización del estado** del clúster
4. **Validaciones adicionales** (pueden extenderse)

## 📁 Estructura del Rol

```
roles/validacion/
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

## ✅ Validaciones Ejecutadas

### 1. Estado del Clúster Patroni

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

### 2. Información del Sistema

El rol también muestra el contenido de `/etc/rocky-release` o el archivo de release correspondiente para confirmar el sistema operativo.

## 📊 Indicadores de Éxito

### ✅ Clúster Saludable

- **Leader**: Exactamente 1 nodo con rol "Leader"
- **State**: Todos los nodos en estado "running"
- **Lag**: Réplicas con lag 0 o cercano a 0
- **Timeline**: Todos los nodos en el mismo timeline (TL)

### ❌ Problemas Potenciales

- **No Leader**: Ningún nodo es Leader
- **Multiple Leaders**: Más de un Leader (split-brain)
- **State != running**: Nodos en estado "stopped" o "starting"
- **Lag alto**: Réplicas con lag > 10MB
- **Timeline diferente**: Nodos en diferentes timelines

## 📝 Ejemplo de Uso

### En un Playbook

```yaml
---
- name: Validar clúster PostgreSQL HA
  hosts: postgresql_servers
  become: true

  roles:
    - validacion
```

### Con Tags

```bash
ansible-playbook -i inventory/hosts postgresql-ha.yml --tags validacion
```

### Ejecutar Solo Validaciones

```bash
# Crear playbook solo de validación
cat > validate-cluster.yml << 'EOF'
---
- name: Validar Clúster PostgreSQL HA
  hosts: postgresql_servers[0]
  become: true

  tasks:
    - name: Ejecutar validaciones
      include_role:
        name: validacion
EOF

ansible-playbook -i inventory/hosts validate-cluster.yml
```

## 🧪 Pruebas de Failover

### Test 1: Failover Automático

```bash
#!/bin/bash
# test_automatic_failover.sh

echo "=== TEST DE FAILOVER AUTOMÁTICO ==="
echo "ADVERTENCIA: Este test detendrá el master actual"
read -p "¿Continuar? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Identificar master actual
    MASTER=$(patronictl -c /etc/patroni/patroni.yml list | grep Leader | awk '{print $2}')
    echo "Master actual: $MASTER"

    # Detener Patroni en el master
    echo "Deteniendo Patroni en $MASTER..."
    ssh $MASTER "sudo systemctl stop patroni"

    # Esperar failover
    echo "Esperando failover (30s)..."
    sleep 30

    # Verificar nuevo master
    echo "Nuevo estado del clúster:"
    patronictl -c /etc/patroni/patroni.yml list

    # Restaurar servicio
    echo "Restaurando servicio en $MASTER..."
    ssh $MASTER "sudo systemctl start patroni"
fi
```

### Test 2: Switchover Planificado

```bash
#!/bin/bash
# test_planned_switchover.sh

echo "=== TEST DE SWITCHOVER PLANIFICADO ==="

# Estado actual
echo "Estado actual:"
patronictl -c /etc/patroni/patroni.yml list

# Ejecutar switchover
echo -e "\nEjecutando switchover..."
patronictl -c /etc/patroni/patroni.yml switchover --force

# Verificar resultado
echo -e "\nNuevo estado:"
sleep 10
patronictl -c /etc/patroni/patroni.yml list
```

## 🐛 Troubleshooting de Validaciones

### Si patronictl no funciona

```bash
# Verificar que el binario existe
which patronictl

# Verificar configuración
ls -la /etc/patroni/patroni.yml

# Ejecutar con path completo
/usr/local/bin/patronictl -c /etc/patroni/patroni.yml list

# Ver logs de Patroni
journalctl -u patroni -n 50
```

### Si no hay Leader en el clúster

```bash
# Verificar etcd
etcdctl get /db/postgres --prefix

# Forzar elección de leader
patronictl -c /etc/patroni/patroni.yml resume

# Verificar logs de todos los nodos
for node in server-node1 server-node2 server-node3; do
    echo "=== $node ==="
    ssh $node "journalctl -u patroni -n 20 | grep -i error"
done
```

### Si hay lag alto en réplicas

```bash
# Verificar estado de replicación
psql -h master-ip -U postgres -c "SELECT * FROM pg_stat_replication;"

# Verificar slots de replicación
psql -h master-ip -U postgres -c "SELECT * FROM pg_replication_slots;"

# Verificar configuración de wal
psql -h master-ip -U postgres -c "SHOW wal_keep_segments;"
```

### Dashboard de Salud

```bash
#!/bin/bash
# health_dashboard.sh

clear
echo "╔════════════════════════════════════════════════════╗"
echo "║         POSTGRESQL HA CLUSTER DASHBOARD            ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Última actualización: $(date)"
echo ""

# Estado general
patronictl -c /etc/patroni/patroni.yml list
```

## 🔗 Dependencias

### Prerequisitos

Todos los roles deben haberse ejecutado exitosamente:

- `common`
- `firewall`
- `etcd`
- `postgresql`
- `patroni`
- `haproxy`
- `keepalived`

## 📄 Licencia

Este rol es parte del proyecto PostgreSQL HA con Patroni y está bajo la misma licencia.

## 🤝 Contribuciones

Para contribuir a este rol:

1. Agregar nuevas validaciones según necesidades
2. Crear scripts de prueba automatizados
3. Documentar casos de fallo y soluciones
4. Mantener compatibilidad con diferentes entornos

---

**Autor**: cgarzont (IS NTTDATA Col)
**Última actualización**: Junio 2025  
**Versión del rol**: 1.0.0
