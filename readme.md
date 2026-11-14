# 🌿 GreenAndCoop — Forecast 2.0 : Pipeline ELT & Infrastructure Cloud AWS

<p align="left">
  <img src="https://img.shields.io/badge/PostgreSQL-15-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Airbyte-abctl-655CFC?style=for-the-badge&logo=airbyte&logoColor=white" alt="Airbyte" />
  <img src="https://img.shields.io/badge/dbt_Core-1.8.2-FF694B?style=for-the-badge&logo=dbt&logoColor=white" alt="dbt" />
  <img src="https://img.shields.io/badge/Docker-Desktop-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/AWS-Stockholm-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white" alt="AWS" />
  <img src="https://img.shields.io/badge/Tests-25%20PASS-success?style=for-the-badge&logo=checkmarx&logoColor=white" alt="Tests" />
</p>

Ce dépôt contient l'infrastructure de données et le pipeline **ELT** (*Extract - Load - Transform*) automatisé du projet **Forecast 2.0** pour **GreenAndCoop**, fournisseur coopératif d'électricité 100 % renouvelable dans les Hauts-de-France.

L'objectif est d'ingérer, nettoyer, vérifier et mettre à disposition des données météo locales fiables pour alimenter les algorithmes de Machine Learning de l'équipe Data Science sous **AWS SageMaker** (prévision de la production éolienne/solaire et anticipation de la consommation du réseau).

---

## 📑 Sommaire

1. [Contexte Métier & Enjeux](#1-contexte-métier--enjeux)
2. [Fonctionnement Global (Approche ELT)](#2-fonctionnement-global-approche-elt)
3. [Modèle de Données (Schéma en Étoile)](#3-modèle-de-données-schéma-en-étoile)
4. [Contrôle Qualité & Fiabilité (25 Tests dbt)](#4-contrôle-qualité--fiabilité-25-tests-dbt)
5. [Sécurité & Confidentialité Git (Zéro-Leak)](#5-sécurité--confidentialité-git-zéro-leak)
6. [Déploiement Cloud AWS (Stockholm `eu-north-1`)](#6-déploiement-cloud-aws-stockholm-eu-north-1)
7. [Temps de Traitement & Budget FinOps](#7-temps-de-traitement--budget-finops)
8. [Guide de Démarrage Rapide (Quickstart)](#8-guide-de-démarrage-rapide-quickstart)
9. [Organisation des Dossiers du Projet](#9-organisation-des-dossiers-du-projet)

---

## 1. Contexte Métier & Enjeux

Pour maintenir l'équilibre du réseau électrique et éviter d'acheter de l'électricité d'urgence au prix fort sur les marchés, GreenAndCoop doit anticiper la météo avec précision.

Les stations météo officielles laissaient des zones sans mesure dans la région. Nous avons donc intégré **6 stations locales complémentaires** :

| Réseau Source | Stations Raccordées | Type de Station | Fréquence | Format Brut |
| :--- | :--- | :--- | :--- | :--- |
| **InfoClimat** | Lille-Lesquin (`07015`), Armentières (`00052`), Bergues (`000R5`), Hazebrouck (`STATIC0010`) | Professionnelles & Semi-pro | 10 min à 1 h | Fichier JSON imbriqué |
| **Weather Underground** | La Madeleine, FR (`ILAMAD25`) & Ichtegem, BE (`IICHTE19`) | Stations Amateurs | 10 à 15 min | Fichiers Excel (`.xlsx`) |

---

## 2. Fonctionnement Global (Approche ELT)

Le pipeline applique la règle de l'**ELT** : on extrait et on charge les données brutes sans les modifier, puis on effectue l'ensemble des transformations directement dans la base de données PostgreSQL via **dbt Core**.

```text
[ Sources Météo ] ➔ (1. Ingestion Airbyte) ➔ [ PostgreSQL RAW ]
(JSON & Excel)        Pas de filtre / Pur brut    (infoclimat_raw, wu_...)
                                                      │
                                                      ▼
[ Entrepôt Marts ] ◀── (3. Marts) ◀── (2. Intermediate) ◀── (1. Staging)
  Schéma Étoile         Tables finies     Union & Filtres     Nettoyage & °F ➔ °C
  (Index B-Tree)        1 722 lignes      6 stations          Macro clean_numeric
```

### Le rôle de chaque étape :

* **Couche `raw` (Airbyte) :** Stocke les données telles qu'elles arrivent, sans aucun tri ni modification.
* **Couche `staging` (dbt - 4 vues) :** Déplie le JSON d'InfoClimat, retire les unités parasites grâce à la macro `clean_numeric` et convertit les mesures américaines (°F en °C, mph en km/h, inHg en hPa).
* **Couche `intermediate` (dbt - 2 vues) :** Réunit les 6 stations dans une liste commune, ajoute les coordonnées GPS et élimine les doublons sur une même heure grâce à un fenêtrage `ROW_NUMBER()`.
* **Couche `marts` (dbt - 3 tables physiques) :** Construit les tables finales optimisées pour les requêtes des Data Scientists.

---

## 3. Modèle de Données (Schéma en Étoile)

Dans la couche `marts`, les données nettoyées sont organisées selon un schéma en étoile clair et performant :

```text
             ┌──────────────────────────────┐
             │  marts.dim_weather_stations  │
             ├──────────────────────────────┤
             │ PK  station_id               │
             │     station_name, city       │
             │     country, latitude        │
             │     longitude, elevation     │
             │     hardware, software       │
             │     is_amateur (True/False)  │
             └──────────────┬───────────────┘
                            │ 1
                            │
                            │ N
┌──────────────────────┐    │    ┌────────────────────────────────┐
│    marts.dim_date    │    │    │   marts.fct_weather_readings   │
├──────────────────────┤    │    ├────────────────────────────────┤
│ PK  date_id          │1   │   N│ PK  reading_id (Hash MD5)      │
│     full_date (Date) ├────┼────┤ FK  station_id                 │
│     year, month, day │    └───▶│ FK  date_id                    │
│     day_of_week      │         │     recorded_at_utc            │
│     is_weekend (Bool)│         │     temperature_celsius        │
└──────────────────────┘         │     humidity_percentage        │
                                 │     pressure_hpa, wind_speed   │
                                 │     wind_gust, rainfall_1h_mm  │
                                 │     wind_direction_deg         │
                                 │     data_source, ingested_at   │
                                 └────────────────────────────────┘
```

> [!TIP]
> **Performance SQL (< 1 ms) :**
> 11 index B-Tree sont configurés directement dans le code dbt (`config(indexes=[...])`). Le test de performance `EXPLAIN ANALYZE` montre que la lecture d'une série météo utilise un `Index Scan` en seulement **0,94 ms**.

---

## 4. Contrôle Qualité & Fiabilité (25 Tests dbt)

À chaque exécution, dbt lance une batterie complète de **25 tests automatiques** sur les tables :

```text
Finished running 25 data tests in 0 hours 0 minutes and 6.07 seconds.
Completed successfully
Done. PASS=25 WARN=0 ERROR=0 SKIP=0 TOTAL=25
```

### Détail des 25 contrôles :

1. **22 tests structurels génériques :**
   * **Unicité :** Aucun identifiant en double sur les stations, les dates et les mesures météo (`reading_id`).
   * **Non-nullité :** Aucun champ obligatoire n'est vide (`not_null`).
   * **Intégrité référentielle :** Aucun relevé orphelin (`relationships` : chaque mesure est obligatoirement rattachée à une station et à une date existantes).
   * **Domaines de valeurs :** Les pays sont limités à la France et à la Belgique (`accepted_values`).
2. **3 tests métier singuliers (SQL dans `tests/`) :**
   * **Plage de température réaliste :** Vérifie qu'aucune valeur ne dépasse l'intervalle [-50 °C ; +60 °C].
   * **Pression atmosphérique normale :** Vérifie que la pression se situe bien entre 870 hPa et 1085 hPa.
   * **Absence d'horodatages futurs :** Rejette les relevés dont la date dépasse le jour d'ingestion (horloges de capteurs déréglées).

---

## 5. Sécurité & Confidentialité Git (Zéro-Leak)

Pour protéger le projet lors de sa publication sur GitHub et de son déploiement dans le Cloud, une séparation stricte est appliquée entre le code source et les identifiants sensibles :

> [!IMPORTANT]
> **Aucun secret n'est écrit en clair dans le code ni dans l'image Docker :**
> * **Fichier `.env` :** Stocke vos vrais identifiants en local. Il est bloqué par le `.gitignore` et ne part **jamais** sur GitHub.
> * **Fichier `.env.example` :** Modèle public envoyé sur GitHub avec des valeurs d'exemple pour guider l'installation.
> * **`compose.yml` & `profiles.yml` :** Utilisent uniquement des variables d'environnement (`${LOCAL_POSTGRES_USER}`, `{{ env_var('PGPASSWORD') }}`).

### Comment les variables d'environnement sont gérées et protégées :

1. **En environnement local (Docker Compose & dbt) :**
   * Au démarrage (`docker compose up -d`), Docker Compose lit automatiquement le fichier `.env` local et injecte les variables (`LOCAL_PG_USER`, `LOCAL_PG_PASSWORD`, `AWS_RDS_ENDPOINT`, `AWS_RDS_PASSWORD`...) dans la mémoire des conteneurs.
   * Dans `dbt_project/profiles.yml`, dbt récupère dynamiquement ces valeurs à l'exécution via la fonction Jinja `{{ env_var('...') }}` sans aucune valeur de repli sensible inscrite en dur.
2. **En environnement Cloud AWS (Amazon ECR & ECS Fargate) :**
   * **Image Docker neutre (`Dockerfile.prod`) :** L'image poussée sur Amazon ECR contient uniquement Python, dbt et le code SQL/YAML du projet — **aucun fichier `.env` ni mot de passe n'y est copié**.
   * **Injection protégée au niveau de la tâche ECS :** Les accès à la base de production (`AWS_RDS_ENDPOINT`, `AWS_RDS_USER`, `AWS_RDS_PASSWORD`) sont renseignés uniquement dans la définition de tâche **ECS Fargate** (`ecs-dbt-task.json`). AWS les injecte en mémoire vive uniquement pendant les 3,5 secondes d'exécution du conteneur, puis détruit le conteneur dès la fin du traitement *(extensible via **AWS Secrets Manager** en production avancée)*.
   * **Protection Git & Gabarits `.example` :** Les fichiers de configuration AWS réels (`ecs-dbt-task.json`, `eventbridge-target.json`) sont exclus du dépôt via `.gitignore`. Des gabarits anonymisés (`ecs-dbt-task.json.example` et `eventbridge-target.json.example`) sont fournis à la racine pour reproduire l'infrastructure.

---

## 6. Déploiement Cloud AWS (Stockholm `eu-north-1`)

L'infrastructure Cloud assure la disponibilité continue de l'entrepôt et l'exécution automatisée sans serveur :

```text
[ Ingestion Airbyte ] ──▶ [ Amazon RDS PostgreSQL ] ◀── [ AWS ECS Fargate ] ◀── [ Amazon EventBridge ]
 (Transit sécurisé SSL)     Instance de production        Tâche batch dbt-prod     Déclencheur 06h00 UTC
                                       │                            │
                                       ▼                            ▼
                              [ Chiffrement KMS ]          [ Amazon CloudWatch ]
                              Backups auto (7 jours)       Logs (/ecs/dbt-prod)
```

* **Base de données managée (Amazon RDS PostgreSQL 15) :** Instance `db.t4g.micro` chiffrée avec AWS KMS, bénéficiant de sauvegardes automatiques quotidiennes conservées 7 jours.
* **Calcul Serverless (AWS ECS Fargate) :** L'image Docker de production est stockée sur **Amazon ECR**. Chaque matin, Fargate exécute la tâche dbt en 3,5 secondes puis s'éteint immédiatement.
* **Planification (Amazon EventBridge) :** Règle automatique déclenchant le run quotidien à 06h00 UTC (`cron(0 6 * * ? *)`).
* **Supervision (Amazon CloudWatch) :** Centralisation des traces d'exécution avec rétention fixée à 7 jours.

### 6.1 Préparer le compte AWS et connecter VS Code

1. **Sur la console Web AWS :**
   * Sélectionnez la région **Europe (Stockholm) `eu-north-1`** en haut à droite.
   * Ouvrez le service **IAM** ➔ **Utilisateurs** ➔ **Créer un utilisateur**, et attachez-lui la permission `AdministratorAccess`.
   * Dans l'onglet **Informations d'identification de sécurité**, créez une **Clé d'accès** (pour interface en ligne de commande CLI) afin de récupérer votre `Access Key ID` et votre `Secret Access Key`.
2. **Dans le terminal PowerShell de VS Code (Windows) :**
   ```powershell
   # Installer l'outil en ligne de commande AWS CLI sous Windows
   winget install Amazon.AWSCLI

   # Connecter votre terminal VS Code à votre compte AWS
   aws configure
   # (Saisir : Access Key ID, Secret Access Key, région "eu-north-1", format "json")

   # Vérifier que VS Code est bien connecté au compte AWS
   aws sts get-caller-identity
   ```

### 6.2 Empaqueter le projet dbt dans Docker et l'envoyer sur AWS (ECR)

AWS ne lit pas directement les fichiers présents sur votre ordinateur ni sur GitHub. Il faut donc empaqueter tout le dossier `dbt_project` dans une image Docker (`Dockerfile.prod`) et l'envoyer dans le magasin privé **Amazon ECR** depuis VS Code :

```powershell
$REGION = "eu-north-1"
$ACCOUNT_ID = "<VOTRE_ACCOUNT_ID>"
$ECR_URI = "$ACCOUNT_ID.dkr.ecr.$[REGION.amazonaws.com/greenandcoop/dbt-prod](https://REGION.amazonaws.com/greenandcoop/dbt-prod)"

# 1. Connecter Docker au magasin privé Amazon ECR
$PwdEcr = aws ecr get-login-password --region $REGION
docker login --username AWS --password $PwdEcr "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# 2. Empaqueter (construire) l'image Docker contenant votre projet dbt
docker build -f Dockerfile.prod -t greenandcoop/dbt-prod:latest .

# 3. Étiqueter et envoyer l'image vers Amazon ECR
docker tag greenandcoop/dbt-prod:latest "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"
```

### 6.3 Transférer les données brutes (`raw`) vers Amazon RDS

Comme Airbyte tourne en local sur votre PC, on exporte les 3 tables brutes (`raw`) de notre PostgreSQL local pour les injecter dans la base **Amazon RDS** :

```powershell
$RDS_HOST = "<VOTRE_ENDPOINT_RDS>.eu-north-1.rds.amazonaws.com"

# 1. Exporter le schéma raw local dans un fichier temporaire
docker exec -i -e PGPASSWORD="<MDP_LOCAL>" p8_postgres pg_dump -U <USER_LOCAL> -d greenandcoop_db -n raw --no-owner --no-privileges -f /tmp/raw_full.sql

# 2. Charger les données brutes directement dans la base Amazon RDS
docker exec -i -e PGPASSWORD="<MDP_RDS>" p8_postgres psql -h $RDS_HOST -U <USER_RDS> -d greenandcoop_db -f /tmp/raw_full.sql
```

### 6.4 Lancer l'exécution sur AWS (ECS Fargate) et vérifier les tests

Une fois l'image envoyée sur ECR et les données brutes présentes sur RDS, **ECS Fargate** démarre un conteneur temporaire, exécute `dbt run` pour créer les tables `marts`, puis s'éteint aussitôt :

```powershell
# 1. Déclencher une tâche serverless sur ECS Fargate
aws ecs run-task --region eu-north-1 --cluster "greenandcoop-cluster" --task-definition "greenandcoop-dbt-task" --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_ID>],securityGroups=[<SG_ID>],assignPublicIp=ENABLED}"

# 2. Contrôler les 25 tests qualité directement sur la base Cloud AWS RDS
docker exec -i p8_dbt dbt test --target prod_rds
```

---

## 7. Temps de Traitement & Budget FinOps

### Mesure du délai de mise à disposition (Data SLA)

| Étape du Traitement | Composant Technique | Durée Mesurée |
| :--- | :--- | :--- |
| **1. Ingestion brute** | Airbyte OSS (3 sources vers schéma `raw`) | ~ 20,0 secondes |
| **2. Transformations ELT** | ECS Fargate (`dbt run` sur 4 threads) | 3,52 secondes |
| **3. Certification qualité** | dbt test (25 contrôles sur RDS) | 6,07 secondes |
| **4. Requête analytique** | PostgreSQL RDS (Index Scan B-Tree) | 0,94 milliseconde |
| **TOTAL PIPELINE COMPLET** | **De la source aux tables certifiées** | **< 30 secondes** |

### Maîtrise des coûts (FinOps)
* **RDS PostgreSQL :** Utilisation de l'instance `db.t4g.micro` éligible à l'offre gratuite AWS Free Tier (750 heures/mois).
* **Fargate Serverless :** La tâche dbt ne tournant que quelques secondes par jour, son coût de calcul est inférieur à 0,01 € par mois.
* **Rétention des logs :** Réduite à 7 jours sur CloudWatch pour éliminer tout surcoût de stockage.

---

## 8. Guide de Démarrage Rapide (Quickstart)

### Prérequis
* Docker Desktop & Git
* Airbyte CLI (`abctl`)

### 1. Cloner le projet et préparer l'environnement
```bash
git clone [https://github.com/](https://github.com/)<votre-user>/P8_GreenAndCoop.git
cd P8_GreenAndCoop

# Créer votre fichier d'identifiants à partir du modèle
cp .env.example .env
```

### 2. Démarrer les services locaux
```bash
docker compose up -d

# Raccorder au réseau local d'Airbyte
docker network connect kind p8_postgres
docker network connect kind p8_dbt
docker network connect kind p8_sftp
```

### 3. Exécuter les transformations et les tests dbt
```bash
# Lancer les transformations (9 modèles)
docker exec -i p8_dbt dbt run

# Valider les 25 tests de qualité
docker exec -i p8_dbt dbt test

# Exécuter directement sur la base Cloud AWS RDS
docker exec -i p8_dbt dbt run --target prod_rds
docker exec -i p8_dbt dbt test --target prod_rds
```

### 4. Consulter la documentation et le Lineage DAG
```bash
docker exec -i p8_dbt dbt docs generate
docker exec -d p8_dbt dbt docs serve --port 8085 --host 0.0.0.0
```
Ouvrez votre navigateur sur : **`http://localhost:8086`**

---

## 9. Organisation des Dossiers du Projet

```text
P8_GreenAndCoop/
├── .env.example                    # Modèle public des variables d'environnement
├── .gitignore                      # Exclusion des secrets (.env, JSON AWS) et données
├── compose.yml                     # Configuration Docker locale (Postgres, dbt, SFTP)
├── Dockerfile.prod                 # Image conteneur neutre pour AWS ECR et ECS Fargate
├── ecs-dbt-task.json.example       # Gabarit public de la tâche ECS Fargate
├── eventbridge-target.json.example # Gabarit public du déclencheur EventBridge
├── README.md                       # Documentation technique principale
│
├── airbyte_data/
│   └── local/                      # Fichiers sources météo (JSON et Excel)
│
├── dbt_env/
│   ├── Dockerfile                  # Image d'exécution locale dbt
│   └── requirements.txt            # Dépendances (dbt-core, dbt-postgres, awscli)
│
└── dbt_project/                    # Projet analytique dbt
    ├── dbt_project.yml             # Configuration des schémas et matérialisations
    ├── profiles.yml                # Connexions sécurisées via env_var() (local et prod_rds)
    ├── macros/                     # Macros Jinja (clean_numeric, generate_schema_name)
    ├── models/
    │   ├── staging/                # Vues de nettoyage et conversion des unités
    │   ├── intermediate/           # Vues d'union des stations et dédoublonnage
    │   └── marts/                  # Tables dimensionnelles et index B-Tree
    └── tests/                      # Tests métier SQL (températures, pressions, dates)
```

---

## 👤 Auteur

* **Mikael Godinho** — Projet Forecast 2.0 (GreenAndCoop).