#!/bin/bash

# Configuration
BASE_URL="http://localhost:3000"
EMAIL="renaudtest@test.com"
PASSWORD="renaudtest"

# Fonction pour afficher les résultats
print_result() {
    echo -e "\n\033[1m$1\033[0m"
    echo "Status: $2"
    echo "Response: $3"
    echo "----------------------------------------"
}

# Obtenir le CSRF token depuis le formulaire de connexion
echo "Obtention du CSRF token..."
LOGIN_PAGE=$(curl -s "$BASE_URL/users/sign_in" -c cookies.txt)
CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep -o 'name="authenticity_token" value="[^"]*' | cut -d'"' -f4)

echo "CSRF Token obtenu: $CSRF_TOKEN"

# Test de connexion
echo "Test de connexion..."
LOGIN_RESPONSE=$(curl -v -X POST "$BASE_URL/users/sign_in" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -b cookies.txt -c cookies.txt \
    -d "authenticity_token=$CSRF_TOKEN&user[email]=$EMAIL&user[password]=$PASSWORD" 2>&1)

echo "Réponse de connexion complète :"
echo "$LOGIN_RESPONSE"

# Vérifier si la connexion a réussi (code 303 avec redirection)
if echo "$LOGIN_RESPONSE" | grep -q "HTTP/1.1 303" && echo "$LOGIN_RESPONSE" | grep -q "location: $BASE_URL"; then
    echo "Connexion réussie!"
    
    # Obtenir un nouveau CSRF token après la connexion
    echo "Obtention d'un nouveau CSRF token après connexion..."
    HOME_PAGE=$(curl -s "$BASE_URL" -b cookies.txt)
    CSRF_TOKEN=$(echo "$HOME_PAGE" | grep -o 'name="csrf-token" content="[^"]*' | cut -d'"' -f3)
else
    echo "Échec de la connexion"
    echo "Cookies sauvegardés :"
    cat cookies.txt
    exit 1
fi

# Test des routes principales
ROUTES=(
    "/trading_configs"
    "/trades"
    "/growth_opportunities"
    "/trading_recommendations"
)

for route in "${ROUTES[@]}"; do
    echo "Test de la route: $route"
    RESPONSE=$(curl -v -X GET "$BASE_URL$route" \
        -H "X-CSRF-Token: $CSRF_TOKEN" \
        -b cookies.txt 2>&1)
    STATUS=$?
    
    if [ $STATUS -eq 0 ]; then
        print_result "$route" "Succès" "$RESPONSE"
    else
        print_result "$route" "Échec" "Code d'erreur: $STATUS"
    fi
    
    sleep 1
done

# Test des actions de refresh
REFRESH_ROUTES=(
    "/growth_opportunities/refresh"
    "/trading_recommendations/refresh"
)

for route in "${REFRESH_ROUTES[@]}"; do
    echo "Test de la route de refresh: $route"
    RESPONSE=$(curl -v -X POST "$BASE_URL$route" \
        -H "X-CSRF-Token: $CSRF_TOKEN" \
        -b cookies.txt 2>&1)
    STATUS=$?
    
    if [ $STATUS -eq 0 ]; then
        print_result "$route" "Succès" "$RESPONSE"
    else
        print_result "$route" "Échec" "Code d'erreur: $STATUS"
    fi
    
    sleep 1
done

# Nettoyage
rm cookies.txt

echo "Tests terminés" 