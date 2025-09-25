# Database Init Role

## Descripción

Este rol de Ansible automatiza la inicialización completa de una base de datos PostgreSQL en un cluster Patroni de alta disponibilidad. El rol detecta automáticamente el nodo líder del cluster y ejecuta todas las operaciones solo en ese nodo para mantener la consistencia.

## Características

- Detección automática del nodo líder Patroni
- Creación de usuario, base de datos y schema
- Configuración de parámetros (search_path, timezone)
- Creación de estructura de tablas con constraints y relaciones FK
- Carga de datos iniciales desde scripts SQL con orden de dependencias
- Generación de informe detallado post-instalación
- Manejo robusto de errores con rescue blocks
- Idempotencia completa

## Requisitos

### Sistema Operativo

- Rocky Linux 9 / RHEL 9 / CentOS 9
- Python 3.x instalado

### Software

- PostgreSQL 17+
- Patroni 4.0+
- Ansible 2.9+

### Módulos de Ansible

```yaml
collections:
  - community.postgresql
```

### Paquetes Python

- `python3-psycopg2`

## Variables del Rol

### Defaults (`defaults/main.yml`)

| Variable      | Descripción                 | Valor por defecto         |
| ------------- | --------------------------- | ------------------------- |
| `db_name`     | Nombre de la base de datos  | `doc-mgr_template-mgr-db` |
| `db_schema`   | Schema de la base de datos  | `mgrtigodb`               |
| `db_user`     | Usuario de la base de datos | `admin_db_gestordoc`      |
| `db_password` | Contraseña del usuario      | `admin_db_1*`             |
| `db_timezone` | Zona horaria de la BD       | `America/Bogota`          |

### Variables Requeridas (desde el playbook o inventario)

| Variable            | Descripción                          | Ejemplo           |
| ------------------- | ------------------------------------ | ----------------- |
| `postgres_user`     | Usuario administrativo de PostgreSQL | `postgres`        |
| `postgres_password` | Contraseña del usuario postgres      | `MySecurePass123` |
| `ansible_host`      | IP del host PostgreSQL               | `192.168.20.80`   |

## Estructura del Rol

```
database_init/
├── defaults/
│   └── main.yml                # Variables por defecto
├── files/
│   ├── 0_value_types.sql       # Script SQL: datos de value_types
│   ├── 1_formalities_1.sql     # Script SQL: datos de formalities
│   ├── 2_templates.sql         # Script SQL: datos de templates
│   └── 3_template_labels_1.sql # Script SQL: datos de template_labels
├── handlers/
│   └── main.yml                # Handlers (vacío actualmente)
├── tasks/
│   ├── main.yml                # Orquestador principal
│   ├── prerequisites.yml       # Instalación de dependencias
│   ├── check_leader.yml        # Verificación nodo líder Patroni
│   ├── create_database.yml     # Creación de usuario, DB y schema
│   ├── configure_database.yml  # Configuración de parámetros
│   ├── create_tables.yml       # Creación de estructura de tablas
│   ├── apply_constraints.yml   # Aplicación de constraints y FKs
│   ├── load_data.yml           # Carga de datos desde SQL
│   └── generate_report.yml     # Generación de informe final
└── README.md
```

## Ejemplo de Uso

### Playbook básico

```yaml
---
- name: Inicializar Base de Datos PostgreSQL
  hosts: pgcluster
  become: yes
  vars:
    postgres_user: postgres
    postgres_password: "{{ vault_postgres_password }}"

  tasks:
    - name: ROLE - Inicializar la DB
      ansible.builtin.include_role:
        name: database_init
        apply:
          tags: database_init
      tags: ["database_init"]
```

### Inventario de ejemplo

```ini
[pgcluster]
rocky9node1 ansible_host=192.168.20.80
rocky9node2 ansible_host=192.168.20.82
```

## Tags Disponibles

| Tag                 | Descripción                     |
| ------------------- | ------------------------------- |
| `database_init`     | Ejecuta el rol completo         |
| `prerequisites`     | Solo instala prerrequisitos     |
| `leader_check`      | Solo verifica el nodo líder     |
| `database_creation` | Solo crea usuario, DB y schema  |
| `database_config`   | Solo configura parámetros de DB |
| `table_creation`    | Solo crea estructura de tablas  |
| `apply_constraints` | Solo aplica constraints y FKs   |
| `data_loading`      | Solo carga datos desde SQL      |
| `report`            | Solo genera el informe final    |

## Flujo de Ejecución

```mermaid
graph TD
    A[Inicio] --> B[Instalar Prerrequisitos]
    B --> C[Verificar Nodo Líder]
    C --> D{¿Es Líder?}
    D -->|No| Z[Fin]
    D -->|Sí| E[Crear Usuario/DB/Schema]
    E --> F[Configurar Parámetros]
    F --> G{¿Existen Tablas?}
    G -->|Sí| H[Verificar Datos]
    G -->|No| I[Crear Tablas en Orden]
    I --> I1[1. value_types]
    I1 --> I2[2. document_types]
    I2 --> I3[3. formalities]
    I3 --> I4[4. metadata]
    I4 --> I5[5. templates]
    I5 --> I6[6. template_labels]
    I6 --> J[Aplicar Constraints y FKs]
    J --> H
    H --> K{¿Hay Datos?}
    K -->|Sí| L[Generar Informe]
    K -->|No| M[Cargar Scripts SQL en Orden]
    M --> M1[0_value_types.sql]
    M1 --> M2[1_formalities_1.sql]
    M2 --> M3[2_templates.sql]
    M3 --> M4[3_template_labels_1.sql]
    M4 --> L
    L --> Z
```

## Estructura de Tablas

El rol crea las siguientes tablas con sus relaciones:

### 1. `value_types` (NUEVA)

- Catálogo maestro de tipos de valores
- Primary Key: `name`
- Columnas:
  - `name` (VARCHAR 50): Identificador del tipo
  - `regex` (VARCHAR 100): Expresión regular para validación (futuro)
  - `description` (VARCHAR 255): Descripción del tipo
  - `author` (VARCHAR 50): Autor del registro
  - `creation_date` (INTEGER): Timestamp de creación
  - `last_update` (INTEGER): Timestamp de última actualización

### 2. `document_types`

- Almacena tipos de documentos
- Primary Key: `name`
- Constraints: CHECK en `lifecycle_status`

### 3. `formalities`

- Gestiona trámites formales
- Primary Key: `name`
- Constraints: CHECK en `lifecycle_status`

### 4. `metadata`

- Metadatos de documentos
- Primary Key: `name`
- Foreign Key: `document_type_name` → `document_types(name)`

### 5. `templates`

- Plantillas de documentos
- Primary Key: `(name, version)`
- Constraints: CHECK en `lifecycle_status` y `type`

### 6. `template_labels`

- Etiquetas de plantillas
- Primary Key: `(template_name, template_version, name)`
- Foreign Keys:
  - `(template_name, template_version)` → `templates(name, version)`
  - `value_type` → `value_types(name)`

## Orden de Carga de Datos

La carga de datos respeta las dependencias entre tablas:

1. **value_types** - Debe cargarse PRIMERO (catálogo maestro)
2. **formalities** - Independiente
3. **templates** - Independiente
4. **template_labels** - Depende de `value_types` y `templates`

## Constraints y Validaciones

### Primary Keys

- Todas las tablas tienen primary keys definidas

### Foreign Keys

- `metadata` → `document_types`
- `template_labels` → `templates`
- `template_labels` → `value_types`

### Check Constraints

- `document_types.lifecycle_status`: PUBLISHED, DELETED
- `formalities.lifecycle_status`: PUBLISHED, ARCHIVED, DELETED
- `templates.lifecycle_status`: PUBLISHED, ARCHIVED, DELETED
- `templates.type`: PDF, JASPER

### Índices

- `idx_metadata_document_type`
- `fk_template_labels_templates_idx`
- `idx_template_labels_value_type`

## Informe de Salida

Al finalizar, el rol genera un informe detallado que incluye:

```
╔═══════════════════════════════════════════════════════════════════
║                    RESUMEN DE INICIALIZACIÓN DE BASE DE DATOS
╠═══════════════════════════════════════════════════════════════════
║ Base de Datos: doc-mgr_template-mgr-db
║ Schema: mgrtigodb
║ Usuario: admin_db_gestordoc
╠═══════════════════════════════════════════════════════════════════
║                              ESTADO DE TABLAS
╠═══════════════════════════════════════════════════════════════════
║ value_types         │      8 registros │ Última: 2025-01-17 10:27:42
║ document_types      │     15 registros │ Última: 2025-01-17 10:27:43
║ formalities         │     10 registros │ Última: 2025-01-17 10:27:43
║ metadata            │     25 registros │ Última: 2025-01-17 10:27:43
║ template_labels     │     45 registros │ Última: 2025-01-17 10:27:44
║ templates           │     20 registros │ Última: 2025-01-17 10:27:44
╠═══════════════════════════════════════════════════════════════════
║ TOTAL DE REGISTROS: 123
╚═══════════════════════════════════════════════════════════════════
```

## Troubleshooting

### Error: "No se puede conectar a PostgreSQL"

- Verificar que PostgreSQL esté ejecutándose
- Verificar credenciales en las variables
- Verificar conectividad de red

### Error: "El nodo no es líder"

- El rol solo ejecuta en el nodo líder de Patroni
- Verificar estado del cluster: `patronictl -c /etc/patroni.yml list`

### Error: "Fallo al cargar scripts SQL"

- Verificar que los archivos SQL existan en `files/`
- Verificar permisos de los archivos
- Revisar sintaxis SQL en los scripts
- Verificar orden de carga (dependencias FK)

### Error: "Violación de llave foránea"

- Asegurar que `value_types` se carga antes que `template_labels`
- Verificar que todos los tipos referenciados existan
- Revisar el orden de ejecución de scripts

## Seguridad

- Use Ansible Vault para las contraseñas:
  ```bash
  ansible-vault encrypt_string 'MyPassword' --name 'vault_postgres_password'
  ```
- Limite el acceso al usuario de base de datos creado
- Configure pg_hba.conf apropiadamente
- Revise los permisos de los archivos SQL

## Changelog

### Versión 1.1.0 (Septiembre 2025)

- Añadida tabla `value_types` como catálogo maestro de tipos
- Implementada FK desde `template_labels` hacia `value_types`
- Actualizado orden de carga para respetar dependencias
- Mejorado el manejo de constraints y validaciones
- Actualizada documentación con nuevo flujo

### Versión 1.0.0 (Junio 2025)

- Versión inicial del rol
- Soporte para 5 tablas principales
- Carga automatizada de datos

## Autor

---

**Autor**: cgarzont (NTTDATA)  
**Última actualización**: Septiembre 2025  
**Versión**: 1.1.0
