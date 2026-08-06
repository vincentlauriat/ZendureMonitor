---
title: Installation
---

[🇬🇧 English version](../en/installation.md)

# Installation

## Prérequis

- Un Mac sous **macOS 14 (Sonoma) ou plus récent**.
- Une batterie **Zendure SolarFlow** sur le même réseau local, avec un firmware récent qui embarque l'API locale zenSDK (testé sur SolarFlow 2400 Pro ; les modèles 2400 AC / AC+ / AC Pro, 800 Pro/Plus, 1600 AC+, 3000 Mix AC+ et 4000 Mix qui livrent la même API devraient fonctionner).

Aucun compte Zendure, aucun broker MQTT, aucune clé d'API : tout se passe en local.

## Télécharger et installer

1. Téléchargez le dernier fichier `ZendureMonitor-x.y.z.dmg` depuis la page [Releases](https://github.com/vincentlauriat/ZendureMonitor/releases/latest).
2. Ouvrez le DMG et glissez **ZendureMonitor.app** dans le dossier **/Applications**.
3. Lancez l'application : une icône ☀️ apparaît dans la barre de menu, en haut à droite de l'écran.

## Gatekeeper et notarisation

L'application est **signée avec un certificat Developer ID et notarisée par Apple** : macOS l'ouvre sans avertissement de sécurité. Si vous voulez le vérifier vous-même :

```bash
spctl -a -t exec -vv /Applications/ZendureMonitor.app
# attendu : accepted, source=Notarized Developer ID
```

## Premier lancement : autorisation « réseau local »

Au premier lancement, macOS demande si Zendure Monitor peut **rechercher et se connecter à des appareils sur votre réseau local**. Acceptez : sans cette autorisation, l'application ne peut pas joindre la batterie. En cas de refus (ou de perte de l'autorisation après une mise à jour), voir la [FAQ](faq.md#lautorisation-réseau-local-a-disparu-après-une-mise-à-jour).

## Mises à jour automatiques

Les mises à jour sont livrées directement dans l'application via [Sparkle](https://sparkle-project.org) : quand une nouvelle version est publiée, l'application vous la propose d'elle-même. Vous pouvez aussi vérifier manuellement : cliquez sur l'icône ☀️, puis sur le bouton **⋯** en haut à droite du panneau → **Rechercher des mises à jour…**.

---

[Index](../README.md) | [Premiers pas →](demarrage.md)
