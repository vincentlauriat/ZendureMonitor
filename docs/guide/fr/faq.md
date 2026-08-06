---
title: FAQ et dépannage
---

[🇬🇧 English version](../en/faq.md)

# FAQ et dépannage

## L'autorisation « réseau local » a disparu après une mise à jour

Symptôme : après une mise à jour (ou une réinstallation) de l'application, la batterie n'est plus joignable en Wi-Fi local, alors que rien n'a changé sur le réseau. Cause : le remplacement de l'application dans /Applications peut laisser une inscription LaunchServices périmée, et l'autorisation TCC « réseau local » ne s'applique plus au nouveau bundle.

Dans l'ordre :

1. **Réglages Système → Confidentialité et sécurité → Réseau local** : désactivez puis réactivez l'interrupteur de Zendure Monitor, puis cliquez sur **Réessayer** dans le bandeau du panneau.
2. Si cela ne suffit pas, réenregistrez l'application auprès de LaunchServices puis relancez-la :

   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ZendureMonitor.app
   killall Finder Dock
   ```

3. En dernier recours, redémarrez le Mac.

> Piège de diagnostic : cette autorisation ne s'applique pas aux interfaces VPN. Si la batterie répond via Tailscale mais pas en Wi-Fi local, c'est bien un blocage « réseau local » — testez toujours depuis le LAN.

## Le panneau affiche « Hors ligne » ou « Pas de données »

- **Hors ligne** (valeurs grisées) : l'application a des données mais la batterie ne répond plus depuis plus de 60 secondes. Vérifiez que le SolarFlow est allumé et connecté au Wi-Fi, et que le Mac est sur le même réseau.
- **Pas de données** : aucune connexion n'a encore abouti. Vérifiez l'adresse dans **Réglages → Appareil** (bouton **Tester la connexion**) et l'autorisation réseau local (ci-dessus).
- La recherche Bonjour ne trouve rien ? L'API locale est peut-être désactivée : dans l'application mobile Zendure, ajoutez une intégration **HEMS** puis quittez-la — c'est la méthode documentée pour l'activer durablement.

## Le widget ne se met pas à jour

- Le widget est alimenté par l'application : **elle doit tourner** pour que les données soient fraîches. Au-delà de 15 minutes sans données, le widget se grise volontairement et affiche l'ancienneté du relevé.
- « Ouvrez Zendure Monitor » : lancez l'application une fois pour publier le premier relevé.
- Après une mise à jour de l'application, si le widget a disparu de la liste ou reste figé, réenregistrez l'extension :

  ```bash
  pluginkit -a /Applications/ZendureMonitor.app/Contents/PlugIns/ZendureWidget.appex
  ```

## L'icône de l'application est blanche/générique dans le Finder

Autre séquelle possible d'un remplacement de l'application : l'inscription LaunchServices est périmée. Lancez le `lsregister -f` ci-dessus, et si l'icône reste blanche dans le Finder (mais correcte dans le Dock) :

```bash
touch /Applications/ZendureMonitor.app
killall iconservicesagent Finder
```

## Les données du jour sont incomplètes

L'application intègre l'énergie **pendant qu'elle tourne** : si le Mac est éteint ou en veille une partie de la journée, ces heures manquent au compteur (la production affichée est alors une borne basse). Deux options :

- laisser le Mac allumé avec l'application lancée (activez **Lancer au démarrage de la session** dans Réglages → Général) ;
- installer le [collecteur 24/7](acces-distant.md#le-collecteur-247-optionnel) sur une machine toujours allumée : l'historique devient complet, indépendamment de l'allumage de votre Mac.

## Exporter l'historique en CSV

Dans le panneau, carte **Historique**, cliquez sur le bouton de partage (flèche vers le haut) : l'application enregistre un fichier CSV avec une ligne par jour conservé (jusqu'à 90 jours), colonnes `date,wh`.

## Combien de temps l'historique est-il conservé ?

Les totaux quotidiens sont conservés **90 jours** sur le Mac ; le panneau et le tableau de bord en affichent les 14 derniers. Avec le collecteur 24/7, l'historique complet vit dans la base SQLite du collecteur.

## L'application est-elle sûre pour la batterie ?

La supervision est strictement en **lecture seule** (elle ne fait que lire `GET /properties/report`). Seul l'onglet [Contrôle](controle.md) envoie des commandes, toujours à votre initiative, avec confirmation pour les valeurs à risque.

---

[← Accès distant](acces-distant.md) | [Index](../README.md)
