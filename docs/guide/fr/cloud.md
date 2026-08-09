# Mode Cloud et compteur Smart CT

*Nouveau en 1.10.*

## Le mode Cloud Zendure

Par défaut, l'app lit le SolarFlow **en local** (API zenSDK sur votre réseau) — c'est le mode recommandé : plus rapide, sans dépendre d'Internet. Le mode Cloud est une seconde voie, utile quand l'API locale est inaccessible (appareil décroché du Wi-Fi, Mac hors de la maison sans VPN).

### Activer le mode Cloud

1. Dans l'app mobile Zendure, avec le **compte principal** : *Profil → « Authorization Cloud Key »* (selon la version : *Réglages → Développeur*). Copiez la clé.
2. Dans Zendure Monitor : *Réglages → Appareil*, basculez « Source des données » sur **Cloud Zendure**.
3. Collez la clé, « Tester la clé » (la liste de vos appareils s'affiche), puis « Enregistrer et connecter ».
4. Le statut passe par « Connexion au compte Zendure… » → « Connexion au flux temps réel… » → **« Connecté — données en temps réel »**.

Les données arrivent alors en **MQTT temps réel** depuis les serveurs Zendure, où que vous soyez — pas besoin de VPN. Historique, cumuls du jour, alertes de panne et widgets fonctionnent exactement comme en local. Le bas du panneau indique toujours la voie utilisée (locale — hôte principal / de secours, ou Cloud).

### Ce qu'il faut savoir

- **La clé reste sur votre Mac** : elle est conservée dans le trousseau macOS et sert uniquement à obtenir les identifiants MQTT auprès de Zendure. Le jeton brut ne quitte jamais la machine.
- **Lecture seule** : l'onglet Contrôle est désactivé en mode Cloud. Pour piloter la batterie (mode AC, limites), repassez en mode API locale.
- Un compte **partagé** ne fonctionne pas (liste d'appareils vide) : utilisez la clé du compte principal.
- Si le flux s'interrompt, l'app se reconnecte toute seule (nouvelle session complète en ~15 s).

## Le compteur Smart CT

Si un **Zendure SmartMeter3CT** est posé dans votre tableau électrique, l'app peut afficher ce que le SolarFlow ne sait pas : le **soutirage réel de la maison sur le réseau public** et sa **consommation totale**.

1. *Réglages → Réseau → « Compteur Smart CT »* : cliquez **« Détecter sur le réseau »** (le compteur s'annonce en Bonjour, comme le SolarFlow), puis « Utiliser » et « Tester ».
2. Dans le tableau de bord, l'arc **Réseau → Maison** du schéma de flux devient un vrai flux mesuré (animé, avec sa puissance), et le nœud Maison affiche la consommation totale (réseau + injection du SolarFlow). La note sous le schéma détaille les trois phases.

Le Smart CT est interrogé **en local uniquement** — le cloud Zendure ne relaie pas ses mesures. Hors de la maison (sans VPN), l'arc repasse honnêtement en « non mesuré » plutôt que d'afficher une valeur figée.

---

← [Accès distant](acces-distant.md) · [FAQ et dépannage](faq.md) →
