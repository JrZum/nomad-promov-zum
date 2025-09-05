#!/bin/bash

# Script para corrigir o build se o Vite não processar o index.html corretamente

echo "=== Verificando se o build do Vite funcionou corretamente ==="

if [ -f "/app/dist/index.html" ]; then
    echo "index.html encontrado, verificando conteúdo..."
    
    # Verificar se ainda há referências para /src/main.tsx
    if grep -q "/src/main.tsx" /app/dist/index.html; then
        echo "PROBLEMA: index.html ainda referencia /src/main.tsx"
        echo "Corrigindo automaticamente..."
        
        # Encontrar o arquivo JS principal
        MAIN_JS=$(find /app/dist/assets -name "index-*.js" | head -1)
        
        if [ -n "$MAIN_JS" ]; then
            # Extrair apenas o nome do arquivo
            MAIN_JS_NAME=$(basename "$MAIN_JS")
            echo "Arquivo JS principal encontrado: $MAIN_JS_NAME"
            
            # Substituir a referência no index.html
            sed -i "s|/src/main.tsx|/assets/$MAIN_JS_NAME|g" /app/dist/index.html
            echo "Referência corrigida com sucesso!"
        else
            echo "ERRO: Arquivo JS principal não encontrado!"
            exit 1
        fi
    else
        echo "✅ Build do Vite funcionou corretamente - sem referências /src/main.tsx"
    fi
    
    echo "=== Conteúdo final do index.html ==="
    cat /app/dist/index.html
else
    echo "ERRO: index.html não encontrado!"
    exit 1
fi