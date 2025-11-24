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

Antes de ejecutar el script, es necesario crear un archivo de configuración con extensión `.env` que contenga las conexiones a las bases de datos.

### Crear archivo `.env`

1. Crea un archivo con extensión `.env` (por ejemplo: `.ejemplo.env`, `.produccion.env`, `.desarrollo.env`):
```bash
touch .ejemplo.env
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
- **El archivo DEBE terminar en `.env`** por cuestiones de seguridad. El script validará esto antes de ejecutarse.
- Los archivos que terminan en `.env` están incluidos en `.gitignore` para proteger tus credenciales. **Nunca** subas estos archivos al repositorio.
- Puedes crear múltiples archivos `.env` para diferentes entornos (por ejemplo: `.desarrollo.env`, `.produccion.env`, `.ejemplo.env`).
- **Se recomienda usar permisos restrictivos** en los archivos `.env`:
  ```bash
  chmod 600 .ejemplo.env
  ```
- El script utiliza archivos temporales seguros para las credenciales, evitando que las contraseñas aparezcan en la lista de procesos del sistema.
- Las contraseñas se limpian automáticamente de la memoria al finalizar la ejecución.

## 💻 Uso

Ejecuta el script desde la raíz del proyecto pasando el archivo `.env` como parámetro obligatorio:

```bash
./mysql-schema-diff.sh <archivo.env>
```

**Ejemplos:**

```bash
# Usar un archivo de configuración específico
./mysql-schema-diff.sh .ejemplo.env

# Usar otro archivo de configuración
./mysql-schema-diff.sh .produccion.env

# Usar un archivo con nombre descriptivo
./mysql-schema-diff.sh .servidor_carlos.env
```

⚠️ **Requisitos**:
- El archivo `.env` es **obligatorio** como parámetro
- El archivo **debe terminar en `.env`** por cuestiones de seguridad
- El archivo debe existir en la ruta especificada

El script te pedirá confirmación antes de comenzar la comparación:

```
¿Continuar? (s/n):
```

Responde `s` o `S` para continuar, o cualquier otra tecla para cancelar.

## 🔧 Funcionamiento

El script realiza las siguientes operaciones:

### 1. Carga de configuración

- Valida que se haya pasado el archivo `.env` como parámetro
- Verifica que el archivo termine en `.env` por cuestiones de seguridad
- Verifica que el archivo exista
- Lee el archivo `.env` especificado y carga las variables de entorno
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
$ ./mysql-schema-diff.sh .ejemplo.env

📄 Cargando variables desde: .ejemplo.env
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

### Error: "No se ha especificado el archivo .env"

Debes pasar el archivo `.env` como parámetro obligatorio. Ejemplo:
```bash
./mysql-schema-diff.sh .ejemplo.env
```

### Error: "El archivo debe terminar en .env por cuestiones de seguridad"

El archivo que pases como parámetro debe terminar en `.env`. Esto es una medida de seguridad para asegurar que los archivos de configuración sean ignorados por git. Ejemplo válido: `.ejemplo.env`, `.produccion.env`

### Error: "No se encontró el archivo .env"

Asegúrate de que el archivo `.env` especificado existe en la ruta indicada y contiene todas las variables requeridas. Verifica la ruta relativa o absoluta del archivo.

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

## 🔒 Seguridad

Este script implementa varias medidas de seguridad:

- ✅ **Validación de path traversal**: Previene el acceso a archivos fuera del directorio del proyecto mediante validación de rutas
- ✅ **Validación de extensión `.env`**: Requiere que el archivo de configuración termine en `.env` para asegurar que sea ignorado por git
- ✅ **Validación de permisos**: Advierte si el archivo `.env` tiene permisos demasiado permisivos (mayores a 600)
- ✅ **Validación de formato**: Verifica que las variables en el archivo `.env` tengan el formato correcto (`VARIABLE=valor`) antes de exportarlas
- ✅ **Credenciales seguras**: Utiliza archivos temporales con permisos restrictivos (600) en lugar de pasar contraseñas por línea de comandos, evitando que aparezcan en la lista de procesos
- ✅ **Limpieza automática**: Elimina archivos temporales de forma segura (usando `shred` si está disponible, o sobrescritura y eliminación)
- ✅ **Limpieza de memoria**: Elimina variables sensibles (`DB1_PASS`, `DB2_PASS`) de la memoria al finalizar la ejecución
- ✅ **Protección contra interrupciones**: Utiliza `trap` para garantizar la limpieza de archivos temporales incluso si el script se interrumpe (Ctrl+C) o termina inesperadamente
- ✅ **Timeout en conexiones**: Implementa timeout de 10 segundos en conexiones MySQL (`--connect-timeout=10`) para evitar que el script se quede colgado indefinidamente
- ✅ **Validación de ejecución como root**: Advierte y solicita confirmación si el script se ejecuta como usuario root para minimizar riesgos de seguridad

### Recomendaciones de seguridad

1. **Permisos del archivo `.env`**: Siempre usa `chmod 600` en tus archivos `.env` para restringir el acceso solo al propietario
2. **No compartir credenciales**: Nunca compartas archivos `.env` con credenciales reales, ni los subas a repositorios públicos
3. **Rotación de contraseñas**: Cambia las contraseñas de las bases de datos regularmente
4. **Usuarios con permisos mínimos**: Usa usuarios de base de datos con solo los permisos necesarios (lectura para este script)
5. **Revisar logs**: Revisa periódicamente los logs de acceso a las bases de datos para detectar accesos no autorizados
6. **No ejecutar como root**: Ejecuta el script con un usuario no privilegiado para minimizar riesgos en caso de compromiso
7. **Manejo de interrupciones**: Si interrumpes el script (Ctrl+C), los archivos temporales con credenciales se limpiarán automáticamente gracias al sistema de `trap`

## 📄 Licencia

Este proyecto está disponible bajo la licencia que especifiques en tu repositorio.

---

**¿Encontraste un problema o tienes una sugerencia?** Abre un issue en el repositorio.
