#!/bin/bash

# Cargar variables de entorno desde .env
if [ -f .env ]; then
    # Cargar variables desde .env, ignorando comentarios y líneas vacías
    while IFS= read -r line || [ -n "$line" ]; do
        # Ignorar comentarios y líneas vacías
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        # Exportar la variable
        export "$line"
    done < .env
else
    echo "❌ Error: No se encontró el archivo .env"
    echo "   Por favor, crea un archivo .env con las variables de conexión a las bases de datos"
    exit 1
fi

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


# Función para obtener lista de tablas
get_tables() {
    local host=$1
    local port=$2
    local user=$3
    local pass=$4
    local db=$5
    
    if [ -n "$port" ]; then
        mysql -h "$host" -P "$port" -u "$user" --password="$pass" "$db" -se "SHOW TABLES;" 2>/dev/null
    else
        mysql -h "$host" -P "$port" -u "$user" --password="$pass" "$db" -se "SHOW TABLES;" 2>/dev/null
    fi
}

# Función para exportar estructura de tabla
export_table_schema() {
    local host=$1
    local port=$2
    local user=$3
    local pass=$4
    local db=$5
    local table=$6
    local output_file=$7
    
    if [ -n "$port" ]; then
        mysqldump -h "$host" -P "$port" -u "$user" --password="$pass" \
            --no-data "$db" "$table" | \
            grep -v '^--' | grep -Ev '^/\*!' | \
            sed 's/ AUTO_INCREMENT=[0-9]*//g' | sed 's/DEFINER=`[^`]*`@`[^`]*`//g' > "$output_file" 2>/dev/null
    else
        mysqldump -h "$host" -u "$user" --password="$pass" \
            --no-data "$db" "$table" | \
            grep -v '^--' | grep -Ev '^/\*!' | \
            sed 's/ AUTO_INCREMENT=[0-9]*//g' | sed 's/DEFINER=`[^`]*`@`[^`]*`//g' > "$output_file" 2>/dev/null
    fi
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