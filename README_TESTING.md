# Tests de la gem MistralTranslator

## Types de tests

### 1. Tests unitaires (par défaut)

- Utilisent des mocks et stubs
- Pas besoin de clé API
- Rapides et fiables

### 2. Tests d'intégration

- Marqués avec `:integration`
- Nécessitent `MISTRAL_TEST_API_KEY`
- Utilisent la vraie API Mistral

### 3. Tests VCR

- Marqués avec `:vcr`
- Enregistrent les réponses API
- Rejouent les réponses sans nouvelle requête

## Configuration

### Variables d'environnement

```bash
# Pour les tests d'intégration (optionnel)
export MISTRAL_TEST_API_KEY="votre_cle_de_test"

# Alternative (utilise votre clé principale)
export MISTRAL_API_KEY="votre_cle_principale"
```
