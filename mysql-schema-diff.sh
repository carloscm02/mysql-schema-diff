#!/bin/bash

# Variable global para almacenar archivos temporales que necesitan limpieza
declare -a TEMP_FILES=()

# Función de limpieza para ejecutar al salir o interrumpir
cleanup_on_exit() {
    # Limpiar archivos temporales de credenciales
    for temp_file in "${TEMP_FILES[@]}"; do
        if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
            if command -v shred >/dev/null 2>&1; then
                shred -u "$temp_file" 2>/dev/null || rm -f "$temp_file"
            else
                # Si shred no está disponible, sobrescribir y eliminar
                echo "" > "$temp_file"
                rm -f "$temp_file"
            fi
        fi
    done
    # Limpiar variables sensibles
    unset DB1_PASS DB2_PASS env_vars
    TEMP_FILES=()
}

# Configurar trap para limpiar en caso de salida normal, interrupción o terminación
trap cleanup_on_exit EXIT INT TERM

# Verificar que el script no se ejecute como root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Advertencia: No se recomienda ejecutar este script como root"
    echo "   Ejecutar como root puede ser un riesgo de seguridad"
    read -p "¿Continuar de todos modos? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        exit 1
    fi
fi

# Verificar que se haya pasado el archivo .env como parámetro
if [ -z "$1" ]; then
    echo "❌ Error: No se ha especificado el archivo .env"
    echo "   Uso: $0 <archivo.env>"
    echo "   Ejemplo: $0 .ejemplo.env"
    exit 1
fi

ENV_FILE="$1"

# Validar que no contenga path traversal (../ o rutas absolutas peligrosas)
if [[ "$ENV_FILE" =~ \.\./ ]] || [[ "$ENV_FILE" =~ ^/ ]]; then
    echo "❌ Error: El archivo .env debe estar en el directorio actual o subdirectorios"
    echo "[por medidas de seguridad] NO se permiten rutas absolutas o path traversal (../)"
    exit 1
fi

# Convertir a ruta absoluta y validar
ENV_FILE=$(realpath "$ENV_FILE" 2>/dev/null || echo "$ENV_FILE")
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Verificar que el archivo termine en .env por cuestiones de seguridad
if [[ ! "$ENV_FILE" =~ \.env$ ]]; then
    echo "❌ Error: El archivo debe terminar en .env por cuestiones de seguridad"
    echo "   Los archivos .env son ignorados por git para proteger información sensible"
    echo "   Uso: $0 <archivo.env>"
    echo "   Ejemplo: $0 .ejemplo.env"
    exit 1
fi

# Verificar que el archivo existe
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: No se encontró el archivo $ENV_FILE"
    echo "   Por favor, verifica que el archivo existe y la ruta es correcta"
    exit 1
fi

# Verificar permisos del archivo (debe ser 600 o más restrictivo)
FILE_PERMS=$(stat -c "%a" "$ENV_FILE" 2>/dev/null || stat -f "%OLp" "$ENV_FILE" 2>/dev/null)
if [ -n "$FILE_PERMS" ] && [ "$FILE_PERMS" -gt 600 ]; then
    echo "⚠️  Advertencia: El archivo $ENV_FILE tiene permisos $FILE_PERMS"
    echo "   Se recomienda usar permisos 600 (chmod 600 $ENV_FILE) para mayor seguridad"
    read -p "¿Continuar de todos modos? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        exit 1
    fi
fi

# Función para validar formato de variable
validate_env_line() {
    local line="$1"
    # Debe tener formato VARIABLE=valor (sin espacios alrededor del =)
    if [[ "$line" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
        return 0
    fi
    return 1
}

# Cargar variables de entorno desde el archivo .env especificado
echo "📄 Cargando variables desde: $ENV_FILE"
declare -A env_vars
while IFS= read -r line || [ -n "$line" ]; do
    # Ignorar comentarios y líneas vacías
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
        continue
    fi
    # Validar formato antes de procesar
    if ! validate_env_line "$line"; then
        echo "⚠️  Advertencia: Línea con formato inválido ignorada: ${line:0:50}..."
        continue
    fi
    # Extraer nombre de variable y valor de forma segura
    var_name="${line%%=*}"
    var_name="${var_name// /}"  # Eliminar espacios
    var_value="${line#*=}"
    env_vars["$var_name"]="$var_value"
done < "$ENV_FILE"

# Exportar variables validadas
for var_name in "${!env_vars[@]}"; do
    export "$var_name=${env_vars[$var_name]}"
done

# Colores para el output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

REQUIRED_VARS=(DB1_HOST DB1_PORT DB1_USER DB1_PASS DB1_NAME DB2_HOST DB2_PORT DB2_USER DB2_PASS DB2_NAME)
missing_vars=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo -e "${RED}❌ Error${NC}: Las siguientes variables requeridas no están definidas:"
    for var in "${missing_vars[@]}"; do
        echo -e "   ${YELLOW}$var${NC}"
    done
    exit 1
fi

echo "🚀 Generando archivos de estructura (schema) por tabla para comparación..."
echo -e "📊 Base de datos 1: ${YELLOW}$DB1_NAME${NC} en ${YELLOW}$DB1_HOST${NC}:${YELLOW}$DB1_PORT${NC}"
echo -e "📊 Base de datos 2: ${YELLOW}$DB2_NAME${NC} en ${YELLOW}$DB2_HOST${NC}:${YELLOW}$DB2_PORT${NC}"
echo ""

# Confirmación antes de continuar
echo "Esta operación comparará la estructura de las bases de datos indicadas tabla por tabla."
read -p "¿Continuar? (s/n): " confirmacion

if [[ "$confirmacion" != "s" && "$confirmacion" != "S" ]]; then
    echo "❌ Operación cancelada por el usuario"
    echo ""
    exit 0
fi

# Directorio de salida
OUTPUT_DIR="./output"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"


# Función para obtener lista de tablas (sin exponer contraseña)
get_tables() {
    local host=$1
    local port=$2
    local user=$3
    local pass=$4
    local db=$5
    
    # Crear archivo temporal de credenciales
    local temp_cnf=$(mktemp)
    chmod 600 "$temp_cnf"
    cat > "$temp_cnf" << EOF
[client]
host=$host
port=${port:-3306}
user=$user
password=$pass
EOF
    
    # Usar archivo de configuración en lugar de --password
    mysql --defaults-file="$temp_cnf" "$db" -se "SHOW TABLES;" 2>/dev/null
    local result=$?
    
    # Limpiar archivo temporal de forma segura
    if command -v shred >/dev/null 2>&1; then
        shred -u "$temp_cnf" 2>/dev/null || rm -f "$temp_cnf"
    else
        # Si shred no está disponible, sobrescribir y eliminar
        echo "" > "$temp_cnf"
        rm -f "$temp_cnf"
    fi
    
    return $result
}

# Función para exportar estructura de tabla (sin exponer contraseña)
export_table_schema() {
    local host=$1
    local port=$2
    local user=$3
    local pass=$4
    local db=$5
    local table=$6
    local output_file=$7
    
    # Crear archivo temporal de credenciales
    local temp_cnf=$(mktemp)
    chmod 600 "$temp_cnf"
    cat > "$temp_cnf" << EOF
[client]
host=$host
port=${port:-3306}
user=$user
password=$pass
EOF
    
    # Usar archivo de configuración en lugar de --password
    mysqldump --defaults-file="$temp_cnf" --no-data "$db" "$table" 2>/dev/null | \
        grep -v '^--' | grep -Ev '^/\*!' | \
        sed 's/ AUTO_INCREMENT=[0-9]*//g' | \
        sed 's/DEFINER=`[^`]*`@`[^`]*`//g' > "$output_file"
    
    local result=$?
    
    # Limpiar archivo temporal de forma segura
    if command -v shred >/dev/null 2>&1; then
        shred -u "$temp_cnf" 2>/dev/null || rm -f "$temp_cnf"
    else
        # Si shred no está disponible, sobrescribir y eliminar
        echo "" > "$temp_cnf"
        rm -f "$temp_cnf"
    fi
    
    return $result
}

echo "📋 Obteniendo lista de tablas..."

# Obtener tablas de DB1
TABLAS_DB1=$(get_tables "$DB1_HOST" "$DB1_PORT" "$DB1_USER" "$DB1_PASS" "$DB1_NAME")
if [ $? -ne 0 ]; then
    echo "❌ Error al obtener tablas de $DB1_NAME"
    exit 1
fi

# Obtener tablas de DB2
TABLAS_DB2=$(get_tables "$DB2_HOST" "$DB2_PORT" "$DB2_USER" "$DB2_PASS" "$DB2_NAME")
if [ $? -ne 0 ]; then
    echo "❌ Error al obtener tablas de $DB2_NAME"
    exit 1
fi

# Convertir a arrays
readarray -t ARR_DB1 <<< "$TABLAS_DB1"
readarray -t ARR_DB2 <<< "$TABLAS_DB2"

echo "✅ Tablas encontradas:"
echo "   $DB1_NAME: ${#ARR_DB1[@]} tablas"
echo "   $DB2_NAME: ${#ARR_DB2[@]} tablas"
echo ""

# Contadores
TABLAS_PROCESADAS=0
TABLAS_IDENTICAS=0
TABLAS_DIFERENTES=0
TABLAS_SOLO_DB1=0
TABLAS_SOLO_DB2=0

# Procesar cada tabla de DB1
for tabla in "${ARR_DB1[@]}"; do
    if [[ -z "$tabla" ]]; then continue; fi
    
    echo "🔄 Procesando tabla: $tabla"
    
    # Exportar estructura desde DB1
    ARCHIVO_DB1="$OUTPUT_DIR/${DB1_NAME}_${tabla}_schema.sql"
    export_table_schema "$DB1_HOST" "$DB1_PORT" "$DB1_USER" "$DB1_PASS" "$DB1_NAME" "$tabla" "$ARCHIVO_DB1"
    
    if [ $? -ne 0 ]; then
        echo "⚠️  Error al exportar estructura de $tabla desde $DB1_NAME"
        continue
    fi
    
    # Verificar si existe en DB2
    if printf '%s\n' "${ARR_DB2[@]}" | grep -Fxq "$tabla"; then
        # Exportar estructura desde DB2
        ARCHIVO_DB2="$OUTPUT_DIR/${DB2_NAME}_${tabla}_schema.sql"
        export_table_schema "$DB2_HOST" "$DB2_PORT" "$DB2_USER" "$DB2_PASS" "$DB2_NAME" "$tabla" "$ARCHIVO_DB2"
        
        if [ $? -eq 0 ]; then
            # Comparar estructuras
            if diff -q "$ARCHIVO_DB1" "$ARCHIVO_DB2" >/dev/null 2>&1; then
                echo "✅ $tabla: Estructura idéntica - eliminando archivos"
                rm -f "$ARCHIVO_DB1" "$ARCHIVO_DB2"
                ((TABLAS_IDENTICAS++))
            else
                echo "❌ $tabla: Estructura diferente - manteniendo archivos"
                ((TABLAS_DIFERENTES++))
            fi
        else
            echo "⚠️  Error al exportar estructura de $tabla desde $DB2_NAME"
            echo "📝 $tabla: Solo en $DB1_NAME"
            ((TABLAS_SOLO_DB1++))
        fi
    else
        echo "📝 $tabla: Solo existe en $DB1_NAME"
        ((TABLAS_SOLO_DB1++))
    fi
    
    ((TABLAS_PROCESADAS++))
done

# Buscar tablas que solo existen en DB2
for tabla in "${ARR_DB2[@]}"; do
    if [[ -z "$tabla" ]]; then continue; fi
    
    if ! printf '%s\n' "${ARR_DB1[@]}" | grep -Fxq "$tabla"; then
        echo "📝 $tabla: Solo existe en $DB2_NAME"
        
        # Exportar solo desde DB2
        ARCHIVO_DB2="$OUTPUT_DIR/${DB2_NAME}_${tabla}_schema.sql"
        export_table_schema "$DB2_HOST" "$DB2_PORT" "$DB2_USER" "$DB2_PASS" "$DB2_NAME" "$tabla" "$ARCHIVO_DB2"
        
        if [ $? -eq 0 ]; then
            ((TABLAS_SOLO_DB2++))
        fi
    fi
done

echo ""
echo "📊 RESUMEN DE COMPARACIÓN ESTRUCTURAL:"
echo "   Tablas procesadas: $TABLAS_PROCESADAS"
echo "   Estructuras idénticas (eliminadas): $TABLAS_IDENTICAS"
echo "   Estructuras diferentes: $TABLAS_DIFERENTES"
echo "   Solo en $DB1_NAME: $TABLAS_SOLO_DB1"
echo "   Solo en $DB2_NAME: $TABLAS_SOLO_DB2"
echo ""

if [ $TABLAS_DIFERENTES -eq 0 ] && [ $TABLAS_SOLO_DB1 -eq 0 ] && [ $TABLAS_SOLO_DB2 -eq 0 ]; then
    echo "✅ Todas las estructuras son IDÉNTICAS"
    echo "🗑️  Eliminando carpeta temporal..."
    rm -rf "$OUTPUT_DIR"
    echo "✅ Carpeta eliminada. Las estructuras de las bases de datos son iguales."
else
    echo "❌ Se encontraron DIFERENCIAS ESTRUCTURALES"
    echo ""
    echo "📊 Archivos con diferencias guardados en: $OUTPUT_DIR"
    echo ""
    echo "🔍 Para ver las diferencias de una tabla específica:"
    echo "   diff $OUTPUT_DIR/${DB1_NAME}_[tabla]_schema.sql $OUTPUT_DIR/${DB2_NAME}_[tabla]_schema.sql"
    echo ""
    echo "📋 Para comparación visual de una tabla específica:"
    echo "   vimdiff $OUTPUT_DIR/${DB1_NAME}_[tabla]_schema.sql $OUTPUT_DIR/${DB2_NAME}_[tabla]_schema.sql"
    echo ""
    echo "💡 Recomendación: Revisa las diferencias estructurales antes de sincronizar datos."
    
    # Crear resumen
    RESUMEN_FILE="$OUTPUT_DIR/resumen_diferencias_estructura.txt"
    cat > "$RESUMEN_FILE" << EOF
RESUMEN DE DIFERENCIAS ESTRUCTURALES
===================================

Fecha: $(date)
Base de datos 1: $DB1_NAME en $DB1_HOST:$DB1_PORT
Base de datos 2: $DB2_NAME en $DB2_HOST

ESTADÍSTICAS:
- Tablas procesadas: $TABLAS_PROCESADAS
- Estructuras idénticas (eliminadas): $TABLAS_IDENTICAS
- Estructuras diferentes: $TABLAS_DIFERENTES
- Solo en $DB1_NAME: $TABLAS_SOLO_DB1
- Solo en $DB2_NAME: $TABLAS_SOLO_DB2

NOTAS:
- Los archivos de tablas con estructura idéntica fueron eliminados automáticamente
- Solo se conservan los archivos de tablas con diferencias estructurales
- Los archivos terminados en "${DB1_NAME}_[tabla]_schema.sql" provienen de la BD local
- Los archivos terminados en "${DB2_NAME}_[tabla]_schema.sql" provienen de la BD de producción
EOF
    
    echo "📄 Resumen guardado en: $RESUMEN_FILE"
fi
