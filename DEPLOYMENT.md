# Déploiement de Planner

## Architecture

Le portail Wix reste le point d'entrée et contient un lien vers l'application
Flutter Web. Le frontend appelle l'API ASP.NET Core, qui utilise SQL Server.

```text
Wix -> https://planner.example.fr
          |-> Flutter Web
          `-> https://api-planner.example.fr/api -> SQL Server
```

## Configuration du frontend

L'URL de l'API est injectée pendant le build. Elle ne doit pas se terminer par
une barre oblique.

```powershell
flutter build web --release `
  --dart-define=API_BASE_URL=https://api-planner.example.fr/api
```

Le dossier à publier est `planner_front/build/web`. Le fichier
`web/staticwebapp.config.json` fournit le fallback vers `index.html` nécessaire
au rechargement des routes de l'application sur Azure Static Web Apps.

Sans `API_BASE_URL`, le frontend utilise l'adresse locale de développement :
`http://localhost:5120/api`.

## Configuration de l'API

La chaîne de connexion et l'origine du frontend doivent être fournies par la
plateforme d'hébergement ou par des variables d'environnement. Elles ne doivent
pas être ajoutées au dépôt.

```text
ConnectionStrings__DefaultConnection=<chaine SQL Server>
Cors__AllowedOrigins__0=https://planner.example.fr
ASPNETCORE_ENVIRONMENT=Production
```

L'origine CORS est constituée du protocole et du domaine uniquement, sans barre
oblique finale ni chemin.

En production, une origine absente de `Cors:AllowedOrigins` est refusée. En
développement, lorsque la liste est vide, les origines locales sont autorisées
pour permettre `flutter run -d chrome` avec un port dynamique.

## Publication de l'API

```powershell
dotnet publish PlannerAPI.csproj -c Release -o publish
```

La terminaison HTTPS, les journaux persistants, les sauvegardes SQL Server et
la restauration doivent être configurés sur la plateforme retenue avant
l'ouverture au client.
