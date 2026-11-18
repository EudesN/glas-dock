/*
 * Glasdock — weather data from Open-Meteo (free, no API key).
 * The configured city name is sent to Open-Meteo's geocoding service once to
 * find its coordinates; the coordinates are then used for the forecast.
 */
import QtQuick

Item {
    id: data

    property string city: ""
    // GlasDo's built-in weather icons (shared/images/weather) instead of the
    // icon theme's weather icons
    property bool useBadges: true
    property bool fahrenheit: false

    property string place: ""
    property string region: ""      // "State, Country" of the matched place
    property real latitude: NaN
    property real longitude: NaN
    property var current: null    // { temp, feels, humidity, wind, code, isDay }
    property var daily: []        // [{ date, min, max, code }]
    property string error: i18n("Set a city in the settings")
    readonly property bool ready: current !== null
    // the city name gave no match: don't keep asking the geocoder every minute
    property bool cityNotFound: false
    // time of the last successful forecast (ms since epoch, 0 = never)
    property double lastUpdated: 0
    // the shown data is older than two missed refreshes (e.g. offline)
    readonly property bool stale: ready && _now - lastUpdated > 35 * 60 * 1000
    readonly property string updatedText: {
        if (lastUpdated <= 0)
            return "";
        const t = Qt.formatTime(new Date(lastUpdated), Qt.locale().timeFormat(Locale.ShortFormat));
        return stale ? i18n("Offline · updated %1", t) : i18n("Updated %1", t);
    }
    property double _now: Date.now()
    readonly property bool busy: _xhrs.geo !== null || _xhrs.forecast !== null

    onCityChanged: geocode()
    onFahrenheitChanged: if (ready) fetch()

    // one request slot per kind, so a refresh never aborts a geocode (or the
    // other way round); a new request only replaces one of the same kind
    property var _xhrs: ({ geo: null, forecast: null })

    function _setSlot(slot, xhr) {
        const x = Object.assign({}, _xhrs);
        x[slot] = xhr;
        _xhrs = x;
    }

    function request(slot, url, done) {
        const old = _xhrs[slot];
        if (old) {
            old.onreadystatechange = null;
            old.abort();
        }
        const xhr = new XMLHttpRequest();
        _setSlot(slot, xhr);
        xhr.timeout = 10000;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (data._xhrs[slot] === xhr)
                data._setSlot(slot, null);
            if (xhr.status !== 200) {
                data.error = i18n("Weather unavailable");
                return;
            }
            try {
                done(JSON.parse(xhr.responseText));
            } catch (e) {
                data.error = i18n("Weather unavailable");
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // "Paris", "Paris, FR", "Springfield, Illinois" -> { name, qualifier }
    function parseCity(text) {
        const parts = text.split(",").map(p => p.trim()).filter(p => p.length > 0);
        return { name: parts[0] || "", qualifier: parts.slice(1).join(", ") };
    }

    // best geocoding result for the qualifier (country code, country or state)
    function pickResult(results, qualifier) {
        if (!qualifier)
            return results[0];
        const q = qualifier.toLowerCase();
        const match = results.find(r =>
            (r.country_code || "").toLowerCase() === q
            || (r.country || "").toLowerCase().startsWith(q)
            || (r.admin1 || "").toLowerCase().startsWith(q));
        return match || null;
    }

    function geocode() {
        latitude = NaN;
        longitude = NaN;
        current = null;
        daily = [];
        error = "";
        place = "";
        region = "";
        cityNotFound = false;
        lastUpdated = 0;
        const c = parseCity(city);
        if (c.name.length === 0) {
            error = i18n("Set a city in the settings");
            return;
        }
        // names in the system language; more candidates when a qualifier must pick one
        const lang = Qt.locale().name.split("_")[0] || "en";
        request("geo", "https://geocoding-api.open-meteo.com/v1/search?format=json"
                + "&count=" + (c.qualifier ? 20 : 1)
                + "&language=" + encodeURIComponent(lang)
                + "&name=" + encodeURIComponent(c.name), json => {
            const r = json.results && json.results.length > 0 ? data.pickResult(json.results, c.qualifier) : null;
            if (!r) {
                data.cityNotFound = true;
                data.error = i18n("City not found");
                return;
            }
            data.latitude = r.latitude;
            data.longitude = r.longitude;
            data.place = r.name;
            data.region = [r.admin1, r.country].filter(v => v && v !== r.name).join(", ");
            data.fetch();
        });
    }

    function fetch() {
        if (isNaN(latitude) || isNaN(longitude))
            return;
        request("forecast", "https://api.open-meteo.com/v1/forecast?latitude=" + latitude
                + "&longitude=" + longitude
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
                + "&timezone=auto&forecast_days=6"
                + (fahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : ""), json => {
            const d = json.daily, days = [];
            for (let i = 0; i < d.time.length; i++)
                days.push({ date: d.time[i], min: Math.round(d.temperature_2m_min[i]),
                            max: Math.round(d.temperature_2m_max[i]), code: d.weather_code[i] });
            data.daily = days;
            const c = json.current;
            data.current = {
                temp: Math.round(c.temperature_2m),
                feels: Math.round(c.apparent_temperature),
                humidity: Math.round(c.relative_humidity_2m),
                wind: Math.round(c.wind_speed_10m),
                windUnit: data.fahrenheit ? "mph" : "km/h",
                code: c.weather_code,
                isDay: c.is_day === 1
            };
            data.lastUpdated = Date.now();
            data._now = data.lastUpdated;
            data.error = "";
        });
    }

    // WMO weather code -> condition used by the badge set
    function badgeKind(code) {
        if (code === 0) return "clear";
        if (code === 1 || code === 2) return "partly";
        if (code === 3) return "cloudy";
        if (code === 45 || code === 48) return "fog";
        if (code >= 51 && code <= 57) return "drizzle";
        if ((code >= 61 && code <= 65) || (code >= 80 && code <= 82)) return "rain";
        if (code === 66 || code === 67) return "freezing";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
        if (code >= 95) return "storm";
        return "unknown";
    }

    // icon for a WMO code: a badge image, or a Breeze icon name
    function iconFor(code, isDay) {
        if (useBadges)
            return Qt.resolvedUrl("images/weather/" + badgeKind(code) + (isDay === false ? "-night" : "-day") + ".png");
        return themeIconFor(code, isDay);
    }

    // WMO weather code -> Breeze icon name
    function themeIconFor(code, isDay) {
        const n = isDay === false ? "-night" : "";
        if (code === 0) return "weather-clear" + n;
        if (code === 1 || code === 2) return "weather-few-clouds" + n;
        if (code === 3) return "weather-overcast";
        if (code === 45 || code === 48) return "weather-fog";
        if (code >= 51 && code <= 57) return "weather-showers-scattered";
        if ((code >= 61 && code <= 65) || (code >= 80 && code <= 82)) return "weather-showers";
        if (code === 66 || code === 67) return "weather-freezing-rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "weather-snow";
        if (code >= 95) return "weather-storm";
        return "weather-none-available";
    }

    function describe(code) {
        if (code === 0) return i18n("Clear");
        if (code === 1) return i18n("Mostly clear");
        if (code === 2) return i18n("Partly cloudy");
        if (code === 3) return i18n("Overcast");
        if (code === 45 || code === 48) return i18n("Fog");
        if (code >= 51 && code <= 57) return i18n("Drizzle");
        if (code >= 61 && code <= 67) return i18n("Rain");
        if (code >= 71 && code <= 77) return i18n("Snow");
        if (code >= 80 && code <= 82) return i18n("Showers");
        if (code === 85 || code === 86) return i18n("Snow showers");
        if (code >= 95) return i18n("Thunderstorm");
        return "";
    }

    Timer {
        // retry after 1 min while there is no data, otherwise refresh every 15 min;
        // nothing to retry when the city does not exist, or a request is in flight
        interval: !data.ready ? 60 * 1000 : 15 * 60 * 1000
        running: data.city.trim().length > 0 && !data.cityNotFound
        repeat: true
        onTriggered: {
            data._now = Date.now();
            if (data.busy)
                return;
            if (isNaN(data.latitude) || isNaN(data.longitude))
                data.geocode();
            else
                data.fetch();
        }
    }
}
