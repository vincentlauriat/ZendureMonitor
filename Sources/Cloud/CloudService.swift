import Foundation

/// Orchestration complète du Cloud Zendure : décodage du Cloud Key, appel
/// deviceList, connexion MQTT, abonnements, poll de secours `getAll`, et
/// fusion des rapports dans un état par appareil.
///
/// Tourne hors MainActor ; publie ses mises à jour via les callbacks
/// `onDevicesChanged` / `onStateChanged` / `onPhaseChanged`, toujours
/// dispatchés sur le main thread.
final class CloudService: @unchecked Sendable {
    /// Les causes distinctes restent distinctes : chaque cas correspond à un
    /// geste utilisateur différent.
    enum Phase: Equatable {
        case notConfigured                 // pas de Cloud Key saisi
        case fetchingDevices               // requête HTTP en cours
        case connectingMQTT
        case live                          // MQTT connecté, données en flux
        case failed(String)                // erreur affichable
    }

    private(set) var phase: Phase = .notConfigured
    private(set) var devices: [ZendureDevice] = []
    private(set) var states: [String: CloudDeviceState] = [:]  // clé = deviceKey

    var onPhaseChanged: ((Phase) -> Void)?
    var onDevicesChanged: (([ZendureDevice]) -> Void)?
    var onStateChanged: ((_ deviceKey: String, _ state: CloudDeviceState) -> Void)?

    private var mqtt: MQTTClient?
    private var pollTimer: DispatchSourceTimer?
    private var reconnectTask: Task<Void, Never>?
    private var messageCounter = 0
    /// Détection de « session takeover » : le broker Zendure n'accepte qu'une
    /// session temps réel par Cloud Key (clientId fourni par le serveur, lié au
    /// compte). Deux clients avec la même clé s'éjectent mutuellement — le
    /// symptôme est une fermeture serveur quelques secondes après chaque
    /// connexion réussie. Ces deux champs ne sont touchés que depuis les
    /// callbacks MQTT (queue série du client).
    private var lastConnectAt: Date?
    private var rapidDropCount = 0
    private let stateQueue = DispatchQueue(label: "fr.lauriat.ZendureMonitor.cloud-state")
    private let pollQueue = DispatchQueue(label: "fr.lauriat.ZendureMonitor.cloud-poll")

    /// Intervalle du poll de secours `properties/read getAll` (secondes) —
    /// les rapports spontanés arrivent en plus, dès que l'appareil publie.
    var pollInterval: Int = 60

    // MARK: - Cycle de vie

    /// Démarre (ou redémarre) la session cloud avec le jeton donné.
    func start(cloudKeyToken: String) {
        stop()
        let token = cloudKeyToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            setPhase(.notConfigured)
            return
        }

        let cloudKey: CloudKey
        do {
            cloudKey = try CloudKey.decode(token)
        } catch {
            setPhase(.failed(String(localized: "Cloud Key invalide : \(error.localizedDescription)")))
            return
        }

        setPhase(.fetchingDevices)
        Task { [weak self] in
            guard let self else { return }
            do {
                let (devices, mqtt) = try await ZendureAPI.fetchDeviceList(cloudKey: cloudKey)
                // Un deviceList réel peut contenir des entrées aux clés vides ;
                // les garder produirait des topics malformés (`iot//…/#`) que
                // certains brokers sanctionnent en fermant la connexion.
                let usable = devices.filter { !$0.deviceKey.isEmpty && !$0.productKey.isEmpty }
                self.stateQueue.sync { self.devices = usable }
                DispatchQueue.main.async { self.onDevicesChanged?(usable) }
                self.connectMQTT(credentials: mqtt, devices: usable)
            } catch {
                // Réseau pas encore remonté (typique juste après un réveil de
                // veille) ou cloud indisponible : sans nouvel essai planifié,
                // la session resterait morte jusqu'à un geste manuel.
                self.scheduleRetry(message: String(localized: "Cloud injoignable : \(error.localizedDescription) — nouvel essai dans 15 s…"))
            }
        }
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        pollTimer?.cancel()
        pollTimer = nil
        mqtt?.onStateChange = nil
        mqtt?.onMessage = nil
        mqtt?.disconnect()
        mqtt = nil
    }

    /// Demande un rafraîchissement immédiat de tous les appareils.
    func requestRefresh() {
        publishGetAll()
    }

    // MARK: - MQTT

    private func connectMQTT(credentials: MQTTCredentials, devices: [ZendureDevice]) {
        setPhase(.connectingMQTT)
        let client = MQTTClient(
            host: credentials.host,
            port: credentials.port,
            clientId: credentials.clientId,
            username: credentials.username,
            password: credentials.password
        )
        mqtt = client

        client.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .connected:
                self.lastConnectAt = Date()
                // Les deux formes de topic : selon le firmware, les appareils
                // publient sur l'une ou l'autre.
                var topics: [String] = []
                for device in devices {
                    topics.append("/\(device.productKey)/\(device.deviceKey)/#")
                    topics.append("iot/\(device.productKey)/\(device.deviceKey)/#")
                }
                client.subscribe(topics: topics)
                self.setPhase(.live)
                self.publishGetAll()
                self.startPollTimer()
            case .disconnected(let reason):
                self.pollTimer?.cancel()
                self.pollTimer = nil
                // Fermeture < 10 s après une connexion réussie : compter les
                // occurrences consécutives pour diagnostiquer un takeover.
                if let connectedAt = self.lastConnectAt,
                   Date().timeIntervalSince(connectedAt) < 10 {
                    self.rapidDropCount += 1
                } else {
                    self.rapidDropCount = 0
                }
                self.lastConnectAt = nil
                self.scheduleReconnect(reason: reason,
                                       suspectedTakeover: self.rapidDropCount >= 3)
            case .idle, .connecting:
                break
            }
        }

        client.onMessage = { [weak self] topic, payload in
            self?.handleMessage(topic: topic, payload: payload)
        }

        client.connect()
    }

    /// Reconnexion : les credentials MQTT peuvent avoir expiré, donc on repart
    /// du deviceList complet (qui re-fournit aussi les credentials MQTT).
    private func scheduleReconnect(reason: String?, suspectedTakeover: Bool = false) {
        if suspectedTakeover {
            scheduleRetry(message: String(localized: "Le serveur coupe la connexion en boucle — une autre intégration utilise probablement la même Cloud Key (Home Assistant, ioBroker, l'app sur un autre Mac…). Le cloud Zendure n'accepte qu'une session temps réel par clé. Nouvel essai dans 15 s…"))
        } else {
            let detail = reason.map { " : \($0)" } ?? ""
            scheduleRetry(message: String(localized: "Connexion MQTT perdue\(detail) — reconnexion dans 15 s…"))
        }
    }

    /// Affiche l'erreur et replanifie un `start()` complet dans 15 s — chemin
    /// commun aux coupures MQTT et aux échecs HTTP du deviceList.
    private func scheduleRetry(message: String) {
        guard reconnectTask == nil else { return }
        setPhase(.failed(message))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, !Task.isCancelled else { return }
            self.reconnectTask = nil
            if let token = KeychainHelper.read(account: KeychainHelper.cloudKeyAccount) {
                self.start(cloudKeyToken: token)
            }
        }
    }

    /// `properties/read` + `getAll` sur chaque appareil — le filet de sécurité
    /// pour forcer un rapport complet (les rapports spontanés sont partiels).
    private func publishGetAll() {
        guard let mqtt else { return }
        // Un seul sync : devices + incrément du compteur (appelé depuis la
        // queue MQTT, la pollQueue ou le main thread — jamais stateQueue).
        let (devices, firstMessageId) = stateQueue.sync {
            messageCounter += self.devices.count
            return (self.devices, messageCounter - self.devices.count + 1)
        }
        for (index, device) in devices.enumerated() {
            let payload: [String: Any] = [
                "properties": ["getAll"],
                "deviceId": device.deviceKey,
                "messageId": firstMessageId + index,
                "timestamp": Int(Date().timeIntervalSince1970),
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload) {
                mqtt.publish(topic: "iot/\(device.productKey)/\(device.deviceKey)/properties/read", payload: data)
            }
        }
    }

    private func startPollTimer() {
        pollTimer?.cancel()
        // JAMAIS sur stateQueue : le handler appelle publishGetAll() qui fait
        // un stateQueue.sync — sur la même queue ce serait un deadlock
        // (crash SIGTRAP __DISPATCH_WAIT_FOR_QUEUE__, vu dans ZendureCloud).
        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now() + .seconds(pollInterval), repeating: .seconds(pollInterval))
        timer.setEventHandler { [weak self] in
            self?.publishGetAll()
        }
        timer.resume()
        pollTimer = timer
    }

    // MARK: - Messages entrants

    private func handleMessage(topic: String, payload: Data) {
        // Découpage en 4 segments max, sous-séquences vides conservées :
        // marche pour `/pk/dk/sous/topic` (1er segment vide) comme pour
        // `iot/pk/dk/sous/topic`.
        let parts = topic.split(separator: "/", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count >= 4 else { return }
        let deviceKey = String(parts[2])
        let subTopic = String(parts[3])

        guard subTopic.hasPrefix("properties/report") || subTopic.hasPrefix("properties/energy") else { return }
        guard let root = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] else { return }

        let updated: CloudDeviceState = stateQueue.sync {
            var state = states[deviceKey] ?? CloudDeviceState()
            state.merge(payload: root)
            states[deviceKey] = state
            return state
        }
        DispatchQueue.main.async { [weak self] in
            self?.onStateChanged?(deviceKey, updated)
        }
    }

    private func setPhase(_ new: Phase) {
        stateQueue.sync { phase = new }
        DispatchQueue.main.async { [weak self] in
            self?.onPhaseChanged?(new)
        }
    }
}
