# MySQL Schema Diff

Herramienta en Bash para comparar la estructura de dos bases de datos MySQL tabla por tabla. Genera reportes claros y conserva solo las diferencias estructurales, facilitando la identificación de discrepancias entre esquemas de bases de datos.

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Instalación](#-instalación)
- [Configuración](#-configuración)
- [Uso](#-uso)
- [Funcionamiento](#-funcionamiento)
- [Salida](#-salida)
- [Ejemplos](#-ejemplos)

## ✨ Características

- 🔍 Comparación tabla por tabla de estructuras de bases de datos MySQL
- 📊 Generación automática de reportes de diferencias
- 🧹 Eliminación automática de archivos de tablas con estructuras idénticas
- 📝 Resumen detallado de diferencias estructurales
- 🎨 Interfaz de línea de comandos con colores y emojis
- ✅ Validación de variables de entorno requeridas
- 🔒 Configuración segura mediante archivo `.env`

## 📦 Requisitos

- Bash (versión 4.0 o superior)
- Cliente MySQL (`mysql` y `mysqldump`)
- Acceso de lectura a ambas bases de datos que se desean comparar

### Verificar instalación de MySQL

```bash
mysql --version
mysqldump --version
```

## 🚀 Instalación

1. Clona o descarga este repositorio:

```bash
git clone <url-del-repositorio>
cd mysql-schema-diff
```

2. Otorga permisos de ejecución al script:

```bash
chmod +x mysql-schema-diff.sh
```

## ⚙️ Configuración

Antes de ejecutar el script, es necesario configurar las conexiones a las bases de datos en el archivo `.env`.

### Crear archivo `.env`

1. Copia el archivo de ejemplo:
```bash
cp .env.example .env
```

2. Edita el archivo `.env` con tus credenciales reales. El formato es el siguiente:

```env
# Configuración de conexión a Base de Datos 1
DB1_HOST=127.0.0.1
DB1_PORT=3306
DB1_USER=usuario_db1
DB1_PASS=contraseña_db1
DB1_NAME=nombre_base_datos_1

# Configuración de conexión a Base de Datos 2
DB2_HOST=host_servidor
DB2_PORT=3306
DB2_USER=usuario_db2
DB2_PASS=contraseña_db2
DB2_NAME=nombre_base_datos_2
```

### Variables de entorno requeridas

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DB1_HOST` | Host de la primera base de datos | `127.0.0.1` o `localhost` |
| `DB1_PORT` | Puerto de la primera base de datos | `3306` |
| `DB1_USER` | Usuario de la primera base de datos | `root` |
| `DB1_PASS` | Contraseña de la primera base de datos | `mi_contraseña` |
| `DB1_NAME` | Nombre de la primera base de datos | `mi_base_datos` |
| `DB2_HOST` | Host de la segunda base de datos | `192.168.1.100` |
| `DB2_PORT` | Puerto de la segunda base de datos | `3306` |
| `DB2_USER` | Usuario de la segunda base de datos | `usuario_remoto` |
| `DB2_PASS` | Contraseña de la segunda base de datos | `otra_contraseña` |
| `DB2_NAME` | Nombre de la segunda base de datos | `base_datos_remota` |

### Notas de seguridad

⚠️ **IMPORTANTE**: 
- El archivo `.env` está incluido en `.gitignore` para proteger tus credenciales. **Nunca** subas este archivo al repositorio.
- El archivo `.env.example` contiene la estructura básica sin credenciales reales y puede ser compartido de forma segura.

## 💻 Uso

Ejecuta el script desde la raíz del proyecto:

```bash
./mysql-schema-diff.sh
```

El script te pedirá confirmación antes de comenzar la comparación:

```
¿Continuar? (s/n):
```

Responde `s` o `S` para continuar, o cualquier otra tecla para cancelar.

## 🔧 Funcionamiento

El script realiza las siguientes operaciones:

### 1. Carga de configuración

- Lee el archivo `.env` y carga las variables de entorno
- Valida que todas las variables requeridas estén definidas
- Muestra información de las bases de datos que se van a comparar

### 2. Obtención de tablas

- Conecta a ambas bases de datos y obtiene la lista de todas las tablas
- Muestra el número de tablas encontradas en cada base de datos

### 3. Exportación de estructuras

Para cada tabla encontrada:

- Exporta la estructura (schema) usando `mysqldump --no-data`
- Normaliza el output eliminando:
  - Comentarios SQL (`--` y `/*!`)
  - Valores de `AUTO_INCREMENT` (para evitar diferencias por datos)
  - Referencias a `DEFINER` (para evitar diferencias por usuarios)

### 4. Comparación

- Compara las estructuras de las tablas que existen en ambas bases de datos
- Identifica tablas que solo existen en una de las dos bases de datos
- Elimina automáticamente los archivos de tablas con estructuras idénticas

### 5. Generación de reportes

- Crea archivos SQL individuales para cada tabla con diferencias
- Genera un archivo de resumen con estadísticas de la comparación
- Muestra un resumen en consola con los resultados

## 📤 Salida

### Directorio de salida

Todos los archivos generados se guardan en el directorio `./output/`.

### Archivos generados

#### Archivos SQL de esquemas

Para cada tabla con diferencias, se generan dos archivos:

- `{DB1_NAME}_{tabla}_schema.sql` - Estructura de la tabla en la primera base de datos
- `{DB2_NAME}_{tabla}_schema.sql` - Estructura de la tabla en la segunda base de datos

**Ejemplo:**
```
output/
├── mi_bd_usuarios_schema.sql
├── produccion_usuarios_schema.sql
├── mi_bd_productos_schema.sql
└── produccion_productos_schema.sql
```

#### Archivo de resumen

`resumen_diferencias_estructura.txt` - Contiene:
- Fecha y hora de la comparación
- Información de conexión de ambas bases de datos
- Estadísticas detalladas de la comparación
- Notas sobre el proceso

### Comportamiento especial

- Si **todas** las estructuras son idénticas, el directorio `output/` se elimina automáticamente
- Si hay diferencias, se conservan solo los archivos de tablas con discrepancias

## 📊 Ejemplos

### Ejemplo 1: Comparación básica

```bash
$ ./mysql-schema-diff.sh

🚀 Generando archivos de estructura (schema) por tabla para comparación...
📊 Base de datos 1: desarrollo en 127.0.0.1:3306
📊 Base de datos 2: produccion en 192.168.1.100:3306

¿Continuar? (s/n): s

📋 Obteniendo lista de tablas...
✅ Tablas encontradas:
   desarrollo: 15 tablas
   produccion: 15 tablas

🔄 Procesando tabla: usuarios
✅ usuarios: Estructura idéntica - eliminando archivos
🔄 Procesando tabla: productos
❌ productos: Estructura diferente - manteniendo archivos
...

📊 RESUMEN DE COMPARACIÓN ESTRUCTURAL:
   Tablas procesadas: 15
   Estructuras idénticas (eliminadas): 13
   Estructuras diferentes: 2
   Solo en desarrollo: 0
   Solo en produccion: 0
```

### Ejemplo 2: Ver diferencias de una tabla específica

```bash
# Usando diff
diff output/desarrollo_productos_schema.sql output/produccion_productos_schema.sql

# Usando vimdiff (comparación visual)
vimdiff output/desarrollo_productos_schema.sql output/produccion_productos_schema.sql
```

### Ejemplo 3: Comparación con tablas únicas

Si una tabla solo existe en una de las bases de datos:

```
📝 tabla_nueva: Solo existe en desarrollo
```

El archivo SQL correspondiente se guardará en `output/` para su revisión.

## 🛠️ Solución de problemas

### Error: "No se encontró el archivo .env"

Asegúrate de que el archivo `.env` existe en la raíz del proyecto y contiene todas las variables requeridas.

### Error: "la variable XXX no está definida"

Verifica que todas las variables en el archivo `.env` estén correctamente definidas y no tengan espacios alrededor del signo `=`.

### Error al conectar a la base de datos

- Verifica que las credenciales en `.env` sean correctas
- Asegúrate de que el servidor MySQL esté accesible desde tu máquina
- Comprueba que el usuario tenga permisos de lectura en las bases de datos

### No se generan archivos en output/

Si todas las estructuras son idénticas, el directorio `output/` se elimina automáticamente. Esto es el comportamiento esperado.

## 📝 Notas adicionales

- El script solo compara **estructuras**, no datos
- Los valores de `AUTO_INCREMENT` se normalizan para evitar falsas diferencias
- Las referencias a `DEFINER` se eliminan para comparaciones más limpias
- El script requiere permisos de lectura en ambas bases de datos

## 📄 Licencia

Este proyecto está disponible bajo la licencia que especifiques en tu repositorio.

---

**¿Encontraste un problema o tienes una sugerencia?** Abre un issue en el repositorio.
