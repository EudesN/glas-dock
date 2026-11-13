/*
 * Glasdock — weather data from Open-Meteo (free, no API key).
 * The configured city name is sent to Open-Meteo's geocoding service once to
 * find its coordinates; the coordinates are then used for the forecast.
 */
import QtQuick

Item {
    id: data

    property string city: ""
    // Glasdock's own badge icons (shared/images/weather) instead of the
    // icon theme's weather icons
    property bool useBadges: true
    property bool fahrenheit: false

    property string place: ""
    property real latitude: NaN
    property real longitude: NaN
    property var current: null    // { temp, feels, humidity, wind, code, isDay }
    property var daily: []        // [{ date, min, max, code }]
    property string error: ""
    readonly property bool ready: current !== null

    onCityChanged: geocode()
    onFahrenheitChanged: fetch()

    function request(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                data.error = "Weather unavailable";
                return;
            }
            try {
                done(JSON.parse(xhr.responseText));
            } catch (e) {
                data.error = "Weather unavailable";
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function geocode() {
        latitude = NaN;
        longitude = NaN;
        current = null;
        daily = [];
        error = "";
        if (city.trim().length === 0) {
            error = "Set a city in the settings";
            return;
        }
        request("https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&name="
                + encodeURIComponent(city.trim()), json => {
            if (!json.results || json.results.length === 0) {
                data.error = "City not found";
                return;
            }
            const r = json.results[0];
            data.latitude = r.latitude;
            data.longitude = r.longitude;
            data.place = r.name;
            data.fetch();
        });
    }

    function fetch() {
        if (isNaN(latitude) || isNaN(longitude))
            return;
        request("https://api.open-meteo.com/v1/forecast?latitude=" + latitude
                + "&longitude=" + longitude
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
                + "&timezone=auto&forecast_days=6"
                + (fahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : ""), json => {
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
            const d = json.daily, days = [];
            for (let i = 0; i < d.time.length; i++)
                days.push({ date: d.time[i], min: Math.round(d.temperature_2m_min[i]),
                            max: Math.round(d.temperature_2m_max[i]), code: d.weather_code[i] });
            data.daily = days;
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
            return Qt.resolvedUrl("images/weather/" + badgeKind(code) + (isDay === false ? "-night" : "-day") + ".svg");
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
        if (code === 0) return "Clear";
        if (code === 1) return "Mostly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 67) return "Rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        if (code === 85 || code === 86) return "Snow showers";
        if (code >= 95) return "Thunderstorm";
        return "";
    }

    Timer {
        interval: 15 * 60 * 1000
        // only while a place is known
        running: !isNaN(data.latitude) && !isNaN(data.longitude)
        repeat: true
        onTriggered: data.fetch()
    }

    Component.onCompleted: geocode()
}
