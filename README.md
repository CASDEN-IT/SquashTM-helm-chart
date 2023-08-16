# squash

chart helm du produit [squash TM](https://www.squashtest.com/)


Il contient l'installation des produits SquashTest suivant :

* SquashTM que l'on nommera `squash` dans la config

* Squash Orchestrator que l'on nommera `squashauto` dans la configuration

# Installation

Cloner ce projet

* Éditer le values.yaml ou copiez le fichier `values.yaml` vers un fichier lié à votre configuration, par exemple `values-my_env.yaml`

* Créer le namespace d'installation de squash :
```
kubectl create ns squash
```

Note : vous pouvez aussi lancer le helm avec l'option `--create-namespace`

* Installer squash 
```
helm upgrade --install squash -f values.yaml . -n squash
```

# Gestion du token d'intégration SquashTm - Squash Orchestrator

Pour que SquashTM se connecte à SquashAuto il est necessaire de généré un token JWT signé par une public key. Le container SquashAuto peut en auto-générer un pour du test, mais il est préférable de générer son propre token signé.

La public key sera à injecter dans le déploiement SquashAuto, config helm : `squashauto.trustedKey.pub_key`

## Générer les clefs pour intégration SquashTm - SquashAuto

Sur un serveur linux avec openssl
```
openssl genrsa -out trusted_key.pem 4096
openssl rsa -pubout -in trusted_key.pem -out trusted_key.pub
```

## Générer le token

* Ajouter la lib crypto

```
sudo -E pip3 install PyJWT==1.7.1
```

* Créer le script python suivant

```
import jwt  # pip install PyJWT[crypto]
with open('trusted_key.pem', 'r') as f: pem = f.read()
with open('trusted_key.pub', 'r') as f: pub= f.read()

# create a signed token
token = jwt.encode({'iss': 'squash orchestrator', 'sub': 'token'}, pem, algorithm='RS512')
print(token)

# verify it
payload = jwt.decode(token, pub, algorithms=['RS512'])
print(payload)
```

* Générer le JWT : 

```
 python3 generate_jwt.py
```

Ce token sera à utiliser dans squashTM au moment de la [Déclaration de serveur squash orchestrator](https://autom-devops-fr.doc.squashtest.com/2023-06/autom/install.html#declaration-du-serveur-squash-orchestrator). Coté squashAuto, il faudra ajouter le contenu `trusted_key.pub` encodé en base 64 dans le values : `squashauto.trustedKey.pub_key`

# Gestion des plugins

Pour la gestion des plugins, ceux-ci doivent être ajoutés dans le folder du container : `/opt/squash-tm/plugins`

Ce helm implémente deux méthodes d'ajout de plugins validées. On switchera entre les méthodes avec la config `squash.plugins.type`

## Approche download des plugins sur internet

- Configurez le `squash.plugins.type: public`
- Ajouter le tableau des url de plugins au format `tar.gz`. Une liste des liens des plugins est disponible [ici](https://tm-fr.doc.squashtest.com/v3/downloads.html) : `squash.plugins.list`


## Approche package registry:

- Configurer le `squash.plugins.type: internal`

1. On depose dépose un `.tgz` du contenu du folder de plugins que l'on veut injecter
2. Le Pod lance un InitContainer pour récuperer ce tgz et le détare dans un volume
3. Le container squash du pod monte ce volume (contenant donc maintenant les plugins + licences) dans le folder `/opt/squash-tm/plugins`

Ici on utilise le package registry Gitlab. On doit donc dans, le cadre d'un registry privé, générer un token d'accès (Ici un `personal access token` Gitlab).

On indiquera donc dans le `value.yaml` :
- Le `squash.plugins.type: internal`
- L'URL/les URLs du package registry gitlab:  `squash.plugins.list`
- Le personal access token du package registry : `squash.plugins.pat`

### Préparer le fichier de plugin

Pour construire le tgz de plugin, se placer dans le dossier où sont présents les plugins et le dossier licence et lancer un tar :
```
tar -cvzf plugins.tgz .
```

Pour  envoyer ce tgz dans le package registry :

À adapter avec l'URL du registry et le token

```
curl --insecure --header "PRIVATE-TOKEN: glpat-XXXXXXXXXXXXXXXX" --upload-file plugins.tgz "https://gitlab.exemple.com/api/v4/projects/624/packages/generic/squash_plugins/0.0.2/plugins.tgz"
```

# Configuration Authentification

Le helm implémente deux modes d'authentification (autre que l'authentification interne), qui peuvent d'ailleurs cohabiter.

**Attention les plugins et la licence premium SquashTest sont nécessaires pour ces deux intégrations**

## LDAP

Pour l'intgégration LDAP, Cf config de la section values `squash.ldap.`

Pour bien comprendre le fonctionnement de l'intégration SquashTest - LDAP : [Documentation Squash LDAP](https://tm-fr.doc.squashtest.com/v3/install-guide/installation-plugins/configurer-plugins-authentification.html#ldap-et-active-directory)

- Activer l'authentification LDAP : `squash.ldap.enabled: true`
- Configuration LDAP
`squash.ldap.searchBase`
`squash.ldap.searchFilter`
`squash.ldap.serverUrl`
- Créer le compte de service pour l'intégration et renseigner les crédentials dans la configuration : `squash.ldap.managerDn` et `squash.ldap.managerPassword`

- Si l'on veut faire cohabiter LDAP avec l'authentification interne Squash : `squash.ldap.provider: "ldap,internal"`


## SAML

Pour l'intégration SAML, Cf `configuration` de la section values `squash.saml.`

### Prérequis SAML

Pour bien comprendre le fonctionnement de l'intégration SquashTest - SAML : [Documentation Squash SAML](https://tm-fr.doc.squashtest.com/v3/install-guide/installation-plugins/configurer-plugins-authentification.html#saml)

Utiliser cette documentation pour mettre en place tous les prérequis (notamment la génération du fichier de metadata `metadata_sp_squash.xml` et le keystore `keystore.jks` pour l'intégration avec le endpoint d'autorisation). Une fois ces deux fichiers générés, créer les secrets associés :

- Le secret `squash-keystore`
```
kubectl create secret generic squash-keystore --from-file=keystore.jks -n squash
```
- Le secret de metadata du endpoint d'autoristation `squash-sp`
```
kubectl create secret generic squash-sp --from-file=metadata_sp_squash.xml -n squash
```

### Configuration SAML

Configurer ensuite le Chart :

- Activer l'authentification SAML : `squash.saml.enabled: true`
- Configuration saml :
`squash.saml.secretSP`
`squash.saml.idpMetadataUrl`
`squash.saml.keystorePassword`
`squash.saml.keystoreCredentials`
`squash.saml.keystoreKey`

- Pour faire de SAML le login par défaut : `squash.saml.defaultLogin: true`

# Base de données PostgreSQL

Ce Chart intègre la possibilité de provisionner automatiquement une base de données PostgreSQL (utilisation du chart PostgreSQL Bitnami).

Cependant en production, il est conseillé d'utiliser un postgres externe, avec toutes les bonnes pratiques de data protection par exemple.

Se référer au tableau de configuration Helm pour l'implémentation et notamment les sections `postgresql.` pour provisionner la base de données avec ce chart, puis les sections  `squash.db.` et `squash.pgCredentials.` pour la configuration de la connection vers la base de données postgres externe ou non.

# Configuration Helm values

Attention en version free l'authentification est local et la scalabilité ne peut donc pas fonctionner (garder un replica 1 sur le déploiement squash).

The following table lists the configurable parameters of the Squash chart and their default values.

| Parameter                | Description             | Default        |
| ------------------------ | ----------------------- | -------------- |
| `certManager` | use a cert manager to manage Ingress certificates | `false` |
| `proxy.enabled` | use a proxy configuration when you want to download resources (for exemple to retrieve squash plugins on internet) | `true` |
| `proxy.httpsProxy` | https proxy config | `"proxy.exemple.com:8080"` |
| `squash.enabled` | enable squashTM component installation | `true` |
| `squash.replicas` | squashtm deployement replicas : keep 1 | `1` |
| `squash.image.repository` | image to use for squashTM | `"squashtest/squash-tm"` |
| `squash.image.tag` | image tag to use for squashTM | `"4.1.0"` |
| `squash.servicePort` | squashTM service port external access | `80` |
| `squash.healthcheck.startupFailureThreshold` | config startup threshold | `30` |
| `squash.healthcheck.startupPeriodSeconds` | config startup period | `10` |
| `squash.ingress.enabled` | enable ingress used | `true` |
| `squash.ingress.host` | host to use in ingress squashTM | `"squashtm.exemple.com"` |
| `squash.ingress.tls.enabled` | enable tls certif | `true` |
| `squash.ingress.tls.clusterIssuer` | if using certmanager, specify the cert issuer | `"letsencrypt-staging"` |
| `squash.saml.enabled` | enable saml auth implementation | `false` |
| `squash.saml.secretKeystore` | secret keystore to retrieve , must be created before | `"squash-keystore"` |
| `squash.saml.secretSP` | secret sp | `"squash-sp"` |
| `squash.saml.idpMetadataUrl` | URL of your auth identity provider | `"https://auth.exemple.fr/samlv2/squash"` |
| `squash.saml.keystorePassword` | password of your keystore | `"XXXXXXXXXX"` |
| `squash.saml.keystoreCredentials` | user of your keystore | `"squashtm"` |
| `squash.saml.keystoreKey` | key of your keystore | `"squashtm"` |
| `squash.saml.defaultLogin` | use saml auth as default login | `true` |
| `squash.ldap.enabled` | enable ldap authentication | `true` |
| `squash.ldap.searchBase` | ldap search base | `"DC=exemple,DC=com"` |
| `squash.ldap.searchFilter` | ldap search filter | `"(sAMAccountName={0})"` |
| `squash.ldap.serverUrl` | use "ldap://exemple.fr.:389" or "ldaps://exemple.fr.:639" | `"ldap://exemple.com.:389"` |
| `squash.ldap.managerDn` | user to access ldap | `"ldapsquash"` |
| `squash.ldap.managerPassword` | password of ldap user | `"xxxxxxxxxxxxx"` |
| `squash.ldap.provider` | Use "ldap,internal" for multiple auth source | `"ldap,internal"` |
| `squash.pgCredentials.user` | If using postgresql.install: true  you need to set the same credentials and adapt the pg host with pg service name. | `"squash"` |
| `squash.pgCredentials.pwd` | If using postgresql.install: true  you need to set the same credentials and adapt the pg host with pg service name. | `"Pa$$word"` |
| `squash.db.name` | db name | `"squash"` |
| `squash.db.host` | db host (service_name.namespace if postgres is internaly in kube) , automaticallay set if using postgresql.install | `"squash-postgres"` |
| `squash.db.port` |  | `"5432"` |
| `squash.plugins.type` | use type "inernal" if you use a package tgz plugins containing all plugin folder you will need a pat acces to package registry in gitlab and put gitlab packahge endpoint in "list" , use type "public" if you want to use a list of public plugins link | `"internal"` |
| `squash.plugins.list` | plugin list url | `"https://gitlab.exemple.fr/api/v4/projects/xxx/packages/generic/squash_plugins/0.0.1/plugins.tgz"` |
| `squash.plugins.pat` | if using plugins.type: internal , personal access token to use when authenticate with registry | `"glpat-xxxxxxxxxxxxxxxxxxx"` |
| `squash.resources.requests.memory` | memory request | `"100Mi"` |
| `squash.resources.requests.cpu` | cpu request | `"0.1"` |
| `squash.resources.limits.memory` | memory limits | `"1800Mi"` |
| `squash.resources.limits.cpu` | cpu limits | `"0.5"` |
| `squashauto.enabled` | enable squash auto Orchestrator resource to deploy | `true` |
| `squashauto.replicas` | replica count of squashauto deployment : keep 1 | `1` |
| `squashauto.image.repository` | image to use for squashauto | `"squashtest/squash-orchestrator"` |
| `squashauto.image.tag` | image tag to use for squashauto | `"3.6.0"` |
| `squashauto.ingress.enabled` | enable ingress if you need to access squash auto externally | `true` |
| `squashauto.ingress.host` | host of squashauto | `"squashauto.exemple.com"` |
| `squashauto.ingress.tls.enabled` | enable tls on ingress squashauto | `true` |
| `squashauto.resources.requests.memory` |  | `"300Mi"` |
| `squashauto.resources.requests.cpu` |  | `"0.1"` |
| `squashauto.resources.limits.memory` |  | `"1800Mi"` |
| `squashauto.resources.limits.cpu` |  | `"0.8"` |
| `squashauto.trustedKey.enabled` | use trusted Key for squashTM - squashauto Orchestrator communication | `true` |
| `squashauto.trustedKey.pub_key` | copie the b64 encoded public key, look documentation to generate a public key | `"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"` |
| `postgresql.install` | enable installation of a bitnami postgres if not using an existing postgres, not to use in prod | `false` |
| `postgresql.global.postgresql.auth.username` | postgres username of local postgres bitnami , use the same in postgres squash config | `"squash"` |
| `postgresql.global.postgresql.auth.password` | postgres password of local postgres bitnami, use the same in postgres squash config | `"pa$$word"` |
| `postgresql.global.postgresql.auth.database` | postgres database of local postgres bitnami, use the same in postgres squash config | `"squash"` |
