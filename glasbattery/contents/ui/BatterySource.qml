/*
 * Glasbattery — live battery and peripheral device model.
 * Combines KDE PowerDevil's BatteryControlModel (laptop + UPower/HID++ mice,
 * keyboards, touchpads, controllers, headsets), BluezQt.DevicesModel, and a
 * direct USB HID battery probe (for 2.4GHz dongles/wired mice like Delux M400)
 * so connecting/disconnecting peripherals updates automatically.
 */
import QtQuick
import org.kde.plasma.private.battery as Battery
import org.kde.bluezqt as BluezQt
import org.kde.plasma.plasma5support as P5Support

Item {
    id: source

    property bool showLaptop: true
    property bool showPeripherals: true
    property bool showBluetooth: true

    // [{ key, name, kind, iconSource, percent, charging, isLaptop, remainingMsec }]
    property var devices: []
    property var usbDevices: []
    property string usbActiveCmd: ""
    property double usbLastProbeAt: 0
    readonly property string usbScriptPath: Qt.resolvedUrl("../scripts/usb_battery.py").toString().replace(/^file:\/\//, "")
    readonly property int count: devices.length
    readonly property bool hasDevices: count > 0
    readonly property var primaryDevice: count > 0 ? devices[0] : null

    visible: false
    width: 0
    height: 0

    onShowLaptopChanged: scheduleRebuild()
    onShowPeripheralsChanged: {
        if (!showPeripherals)
            usbDevices = [];
        else
            probeUsbPeripherals();
        scheduleRebuild();
    }
    onShowBluetoothChanged: scheduleRebuild()

    function iconUrl(kind) {
        return Qt.resolvedUrl("icons/" + kind + ".svg");
    }

    function normalizeName(s) {
        return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function classifyKind(typeStr, nameStr, iconStr, isPowerSupply) {
        if (isPowerSupply) {
            if (/ups/i.test(typeStr + " " + nameStr))
                return "battery";
            return "laptop";
        }
        const hay = (typeStr + " " + iconStr + " " + nameStr).toLowerCase();
        if (/earbud|airpod|qcy[- ]?t|buds|tws|pods|freebuds|earphone|wf-/.test(hay))
            return "earbuds";
        if (/headphone|headset|audio-head|qcy[- ]?h|wh-1000|qc35|qc45|arctis|kraken|hyperx|jbl/.test(hay))
            return "headphones";
        if (/touchpad|trackpad|magic trackpad/.test(hay))
            return "touchpad";
        if (/keyboard|teclado|keychron|mx keys|k380|k400|anne pro/.test(hay))
            return "keyboard";
        if (/mouse|mx master|mx anywhere|g502|g305|g pro|viper|deathadder|basilisk/.test(hay))
            return "mouse";
        if (/gaming|controller|dualsense|dualshock|xbox|8bitdo|gamepad|joy-con/.test(hay))
            return "gamepad";
        if (/phone|iphone|pixel|galaxy|android|pda/.test(hay))
            return "phone";
        return "battery";
    }

    function kindOrder(kind, isLaptop) {
        if (isLaptop) return 0;
        switch (kind) {
        case "earbuds": return 1;
        case "headphones": return 2;
        case "keyboard": return 3;
        case "mouse": return 4;
        case "touchpad": return 5;
        case "gamepad": return 6;
        case "phone": return 7;
        default: return 8;
        }
    }

    Battery.BatteryControlModel {
        id: batModel
        onHasBatteriesChanged: source.scheduleRebuild()
        onPluggedInChanged: source.scheduleRebuild()
        onSmoothedRemainingMsecChanged: source.scheduleRebuild()
        onModelReset: source.scheduleRebuild()
        onRowsInserted: source.scheduleRebuild()
        onRowsRemoved: source.scheduleRebuild()
    }

    Instantiator {
        id: batInst
        model: batModel
        delegate: QtObject {
            required property int index
            required property var model
            readonly property string name: model.PrettyName || "Battery"
            readonly property int percent: model.Percent !== undefined ? Math.round(model.Percent) : -1
            readonly property bool isPowerSupply: model.IsPowerSupply === true
            readonly property int chargeState: model.ChargeState !== undefined ? model.ChargeState : 0
            readonly property string typeName: model.Type ? model.Type.toString() : ""
            readonly property bool pluggedIn: model.PluggedIn === true

            onNameChanged: source.scheduleRebuild()
            onPercentChanged: source.scheduleRebuild()
            onIsPowerSupplyChanged: source.scheduleRebuild()
            onChargeStateChanged: source.scheduleRebuild()
            onTypeNameChanged: source.scheduleRebuild()
            onPluggedInChanged: source.scheduleRebuild()
        }
        onObjectAdded: source.scheduleRebuild()
        onObjectRemoved: source.scheduleRebuild()
    }

    BluezQt.DevicesModel {
        id: bzModel
        onModelReset: source.scheduleRebuild()
        onRowsInserted: source.scheduleRebuild()
        onRowsRemoved: source.scheduleRebuild()
    }

    Instantiator {
        id: bzInst
        model: bzModel
        delegate: QtObject {
            required property int index
            required property var model
            readonly property string name: model.Name || ""
            readonly property string icon: model.Icon || ""
            readonly property bool connected: model.Connected === true
            readonly property var batteryObj: model.Battery
            readonly property int percent: batteryObj ? Math.round(batteryObj.charge) : -1

            onNameChanged: source.scheduleRebuild()
            onIconChanged: source.scheduleRebuild()
            onConnectedChanged: source.scheduleRebuild()
            onPercentChanged: source.scheduleRebuild()
        }
        onObjectAdded: source.scheduleRebuild()
        onObjectRemoved: source.scheduleRebuild()
    }

    function probeUsbPeripherals() {
        if (!showPeripherals || !usbScriptPath)
            return;
        const now = Date.now();
        if (usbActiveCmd !== "" && now - usbLastProbeAt < 4000)
            return;
        if (usbActiveCmd !== "")
            usbExec.disconnectSource(usbActiveCmd);
        const cmd = "python3 '" + usbScriptPath.replace(/'/g, "'\\''") + "'";
        usbActiveCmd = cmd;
        usbLastProbeAt = now;
        usbExec.connectSource(cmd);
    }

    P5Support.DataSource {
        id: usbExec
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (source.usbActiveCmd === sourceName)
                source.usbActiveCmd = "";
            const stdout = (data && data["stdout"]) ? data["stdout"].trim() : "";
            let parsed = [];
            if (stdout.startsWith("[")) {
                try {
                    const arr = JSON.parse(stdout);
                    if (Array.isArray(arr))
                        parsed = arr;
                } catch (e) {}
            }
            source.usbDevices = parsed;
            source.scheduleRebuild();
        }
    }

    Timer {
        id: usbPollTimer
        interval: 15000
        repeat: true
        running: source.showPeripherals
        triggeredOnStart: true
        onTriggered: source.probeUsbPeripherals()
    }

    Timer {
        id: rebuildTimer
        interval: 40
        onTriggered: source.rebuild()
    }

    function scheduleRebuild() {
        rebuildTimer.restart();
    }

    Component.onCompleted: rebuild()

    function rebuild() {
        const bzByNorm = {};
        const bzDevices = [];
        for (let i = 0; i < bzInst.count; i++) {
            const o = bzInst.objectAt(i);
            if (!o || !o.connected)
                continue;
            const norm = normalizeName(o.name);
            bzByNorm[norm] = o;
            if (o.percent >= 0)
                bzDevices.push(o);
        }

        const list = [];
        const seenNorm = {};
        let laptopCount = 0;
        for (let i = 0; i < batInst.count; i++) {
            const b = batInst.objectAt(i);
            if (!b || b.percent < 0 || !b.pluggedIn)
                continue;
            const isLaptop = b.isPowerSupply;
            if (isLaptop && !showLaptop)
                continue;
            if (!isLaptop && !showPeripherals)
                continue;

            const norm = normalizeName(b.name);
            const bzMatch = bzByNorm[norm];
            if (bzMatch && !showBluetooth)
                continue;

            const kind = classifyKind(b.typeName, b.name, bzMatch ? bzMatch.icon : "", isLaptop);
            const charging = b.chargeState === Battery.BatteryControlModel.Charging;
            const label = isLaptop && (b.name === "Battery" || b.name === "") ? "Laptop" : b.name;
            if (isLaptop)
                laptopCount++;

            seenNorm[norm] = true;
            list.push({
                key: (isLaptop ? "bat-" : "per-") + (norm || i) + "-" + i,
                name: label,
                kind: kind,
                iconSource: iconUrl(kind),
                percent: Math.max(0, Math.min(100, b.percent)),
                charging: charging,
                isLaptop: isLaptop,
                remainingMsec: isLaptop && laptopCount === 1 ? Number(batModel.smoothedRemainingMsec || 0) : 0
            });
        }

        if (showPeripherals && showBluetooth) {
            for (let i = 0; i < bzDevices.length; i++) {
                const bz = bzDevices[i];
                const norm = normalizeName(bz.name);
                if (seenNorm[norm])
                    continue;
                seenNorm[norm] = true;
                const kind = classifyKind("", bz.name, bz.icon, false);
                list.push({
                    key: "bz-" + (norm || i),
                    name: bz.name || "Bluetooth",
                    kind: kind,
                    iconSource: iconUrl(kind),
                    percent: Math.max(0, Math.min(100, bz.percent)),
                    charging: false,
                    isLaptop: false,
                    remainingMsec: 0
                });
            }
        }

        if (showPeripherals) {
            for (let i = 0; i < usbDevices.length; i++) {
                const u = usbDevices[i];
                if (!u || u.percent === undefined || u.percent < 0)
                    continue;
                const name = u.name || "USB Mouse";
                const norm = normalizeName(name);
                if (seenNorm[norm])
                    continue;
                seenNorm[norm] = true;
                const kind = u.kind || classifyKind("", name, "", false);
                list.push({
                    key: u.key || ("usb-" + (norm || i)),
                    name: name,
                    kind: kind,
                    iconSource: iconUrl(kind),
                    percent: Math.max(0, Math.min(100, Math.round(u.percent))),
                    charging: u.charging === true,
                    isLaptop: false,
                    remainingMsec: 0
                });
            }
        }

        list.sort((a, b) => {
            const oa = kindOrder(a.kind, a.isLaptop);
            const ob = kindOrder(b.kind, b.isLaptop);
            if (oa !== ob)
                return oa - ob;
            return a.name.localeCompare(b.name);
        });

        devices = list;
    }
}
