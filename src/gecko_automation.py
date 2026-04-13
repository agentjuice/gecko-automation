#!/usr/bin/env python3
"""
Gecko Automation — Water + monitoring system for leopard gecko.

Controls:
  - Peristaltic water pump (via relay on GPIO)

Monitors:
  - BME280 temperature/humidity sensor (I2C)
  - Float switch for water reservoir level (GPIO)

Reports:
  - MQTT (Home Assistant integration)
  - Telegram alerts
  - Web dashboard (Flask)

Note: Feeding is handled by standalone Petbank carousel feeders
with their own built-in timers (no Pi integration needed).
"""

import json
import time
import signal
import sys
import logging
import threading
from datetime import datetime
from pathlib import Path

import schedule

# RPi.GPIO — only import on actual Pi hardware
try:
    import RPi.GPIO as GPIO
    PI_HARDWARE = True
except (ImportError, RuntimeError):
    PI_HARDWARE = False
    print("⚠️  RPi.GPIO not available — running in simulation mode")

# Optional dependencies
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False

try:
    import smbus2
    BME280_AVAILABLE = True
except ImportError:
    BME280_AVAILABLE = False

try:
    from flask import Flask, jsonify
    FLASK_AVAILABLE = True
except ImportError:
    FLASK_AVAILABLE = False

# ============================================
# Configuration
# ============================================

CONFIG_PATH = Path(__file__).parent.parent / "config.json"
LOG_PATH = Path(__file__).parent.parent / "gecko_automation.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("gecko")


def load_config():
    """Load configuration from config.json."""
    if not CONFIG_PATH.exists():
        log.error(f"Config not found at {CONFIG_PATH}. Copy config.example.json → config.json")
        sys.exit(1)
    with open(CONFIG_PATH) as f:
        return json.load(f)


# ============================================
# GPIO Setup
# ============================================

class HardwareController:
    """Controls GPIO pins for water pump."""

    def __init__(self, config):
        self.config = config

        if PI_HARDWARE:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)

            # Relay for water pump (active LOW for most relay modules)
            self.pump_pin = config["water"]["gpio_relay_pin"]
            GPIO.setup(self.pump_pin, GPIO.OUT, initial=GPIO.HIGH)

            # Float switch (pull-up, goes LOW when water is low)
            if config["water_level"]["enabled"]:
                self.float_pin = config["water_level"]["float_switch_gpio_pin"]
                GPIO.setup(self.float_pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

            log.info("GPIO initialized")
        else:
            log.info("Running in simulation mode (no GPIO)")

    def pump_water(self, duration_seconds):
        """Run the peristaltic pump for a set duration."""
        log.info(f"💧 Pumping water for {duration_seconds}s")
        if PI_HARDWARE:
            GPIO.output(self.pump_pin, GPIO.LOW)   # Relay ON
            time.sleep(duration_seconds)
            GPIO.output(self.pump_pin, GPIO.HIGH)   # Relay OFF
        else:
            time.sleep(0.1)  # Simulate
        log.info("💧 Water pump complete")

    def check_water_level(self):
        """Check float switch. Returns True if water OK, False if low."""
        if not self.config["water_level"]["enabled"]:
            return True
        if PI_HARDWARE:
            return GPIO.input(self.float_pin) == GPIO.HIGH
        return True  # Simulation: always OK

    def cleanup(self):
        """Clean up GPIO on shutdown."""
        if PI_HARDWARE:
            GPIO.cleanup()
            log.info("GPIO cleaned up")


# ============================================
# BME280 Sensor
# ============================================

class SensorMonitor:
    """Reads BME280 temperature and humidity via I2C."""

    def __init__(self, config):
        self.config = config
        self.last_reading = {"temperature_f": None, "humidity": None, "timestamp": None}
        self.bus = None

        if BME280_AVAILABLE and config["sensors"]["bme280_enabled"]:
            try:
                self.bus = smbus2.SMBus(1)
                self.address = int(config["sensors"]["bme280_i2c_address"], 16)
                log.info(f"BME280 initialized at {config['sensors']['bme280_i2c_address']}")
            except Exception as e:
                log.warning(f"BME280 init failed: {e}")
                self.bus = None

    def read(self):
        """Read temperature and humidity. Returns dict or None on failure."""
        if self.bus is None:
            return self.last_reading

        try:
            # For actual deployment, install: pip3 install RPi.bme280
            # and use:
            #   import bme280
            #   calibration = bme280.load_calibration_params(self.bus, self.address)
            #   data = bme280.sample(self.bus, self.address, calibration)
            #   temp_f = data.temperature * 9/5 + 32
            #   humidity = data.humidity
            #   self.last_reading = {
            #       "temperature_f": temp_f,
            #       "humidity": humidity,
            #       "timestamp": datetime.now().isoformat()
            #   }

            log.debug("BME280 read (placeholder — install RPi.bme280 for real reads)")
            return self.last_reading

        except Exception as e:
            log.error(f"BME280 read error: {e}")
            return None

    def check_thresholds(self, reading):
        """Check if readings are within safe range. Returns list of alerts."""
        alerts = []
        cfg = self.config["sensors"]

        if reading and reading.get("temperature_f") is not None:
            temp = reading["temperature_f"]
            if temp < cfg["temp_min_f"]:
                alerts.append(f"🥶 Temperature LOW: {temp:.1f}°F (min: {cfg['temp_min_f']}°F)")
            elif temp > cfg["temp_max_f"]:
                alerts.append(f"🔥 Temperature HIGH: {temp:.1f}°F (max: {cfg['temp_max_f']}°F)")

        if reading and reading.get("humidity") is not None:
            hum = reading["humidity"]
            if hum < cfg["humidity_min"]:
                alerts.append(f"💨 Humidity LOW: {hum:.0f}% (min: {cfg['humidity_min']}%)")
            elif hum > cfg["humidity_max"]:
                alerts.append(f"💦 Humidity HIGH: {hum:.0f}% (max: {cfg['humidity_max']}%)")

        return alerts


# ============================================
# Notifications
# ============================================

class Notifier:
    """Sends alerts via Telegram and/or MQTT."""

    def __init__(self, config):
        self.config = config
        self.mqtt_client = None

        # MQTT
        if MQTT_AVAILABLE and config["mqtt"]["enabled"]:
            try:
                self.mqtt_client = mqtt.Client()
                if config["mqtt"]["username"]:
                    self.mqtt_client.username_pw_set(
                        config["mqtt"]["username"],
                        config["mqtt"]["password"]
                    )
                self.mqtt_client.connect(
                    config["mqtt"]["broker"],
                    config["mqtt"]["port"]
                )
                self.mqtt_client.loop_start()
                log.info("MQTT connected")
            except Exception as e:
                log.warning(f"MQTT connection failed: {e}")
                self.mqtt_client = None

    def send_telegram(self, message):
        """Send a Telegram message."""
        cfg = self.config["telegram"]
        if not cfg["enabled"] or not cfg["bot_token"] or not cfg["chat_id"]:
            return

        try:
            import urllib.request
            url = f"https://api.telegram.org/bot{cfg['bot_token']}/sendMessage"
            data = json.dumps({
                "chat_id": cfg["chat_id"],
                "text": message,
                "parse_mode": "HTML"
            }).encode()
            req = urllib.request.Request(url, data=data,
                                        headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=10)
            log.info(f"Telegram sent: {message[:50]}...")
        except Exception as e:
            log.error(f"Telegram send failed: {e}")

    def publish_mqtt(self, topic_suffix, payload):
        """Publish to MQTT."""
        if self.mqtt_client:
            topic = f"{self.config['mqtt']['topic_prefix']}/{topic_suffix}"
            self.mqtt_client.publish(topic, json.dumps(payload), retain=True)

    def notify(self, message, mqtt_topic=None, mqtt_payload=None):
        """Send notification via all configured channels."""
        self.send_telegram(message)
        if mqtt_topic and mqtt_payload:
            self.publish_mqtt(mqtt_topic, mqtt_payload)


# ============================================
# Web Dashboard
# ============================================

def create_web_app(state):
    """Create a minimal Flask status dashboard."""
    if not FLASK_AVAILABLE:
        return None

    app = Flask(__name__)

    @app.route("/")
    def index():
        water_class = "ok" if state.get("water_level_ok", True) else "warn"
        return f"""
        <html>
        <head><title>🦎 Gecko Automation</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="refresh" content="60">
        <style>
            body {{ font-family: -apple-system, sans-serif; background: #1a1a2e; color: #eee;
                   max-width: 600px; margin: 0 auto; padding: 20px; }}
            h1 {{ color: #4ecca3; }}
            .card {{ background: #16213e; border-radius: 12px; padding: 16px; margin: 12px 0; }}
            .ok {{ border-left: 4px solid #4ecca3; }}
            .warn {{ border-left: 4px solid #f39c12; }}
            .error {{ border-left: 4px solid #e74c3c; }}
            .label {{ color: #888; font-size: 0.85em; }}
            .value {{ font-size: 1.3em; font-weight: bold; }}
            .actions {{ margin-top: 20px; }}
            .btn {{ background: #4ecca3; color: #1a1a2e; border: none; padding: 12px 24px;
                    border-radius: 8px; font-size: 1em; cursor: pointer; margin-right: 8px; }}
            .btn:hover {{ background: #3db892; }}
        </style>
        </head>
        <body>
            <h1>🦎 Gecko Automation</h1>
            <div class="card ok">
                <div class="label">Last Water Refill</div>
                <div class="value">{state.get('last_water', 'Never')}</div>
            </div>
            <div class="card {water_class}">
                <div class="label">Water Reservoir</div>
                <div class="value">{'✅ OK' if state.get('water_level_ok', True) else '⚠️ LOW'}</div>
            </div>
            <div class="card ok">
                <div class="label">Temperature</div>
                <div class="value">{state.get('temperature', 'N/A')}</div>
            </div>
            <div class="card ok">
                <div class="label">Humidity</div>
                <div class="value">{state.get('humidity', 'N/A')}</div>
            </div>
            <div class="card">
                <div class="label">System Uptime</div>
                <div class="value">{state.get('uptime', 'N/A')}</div>
            </div>
            <div class="card">
                <div class="label">Feeding</div>
                <div class="value">Managed by Petbank feeders (check cameras)</div>
            </div>
            <div class="actions">
                <button class="btn" onclick="fetch('/api/water',{{method:'POST'}}).then(()=>location.reload())">💧 Manual Water</button>
            </div>
        </body></html>
        """

    @app.route("/api/status")
    def api_status():
        return jsonify(state)

    @app.route("/api/water", methods=["POST"])
    def api_water():
        """Manual water trigger."""
        state["manual_water_requested"] = True
        return jsonify({"status": "water_requested"})

    return app


# ============================================
# Main Loop
# ============================================

class GeckoAutomation:
    """Main application controller."""

    def __init__(self):
        self.config = load_config()
        self.hardware = HardwareController(self.config)
        self.sensors = SensorMonitor(self.config)
        self.notifier = Notifier(self.config)
        self.start_time = datetime.now()
        self.running = True

        self.state = {
            "last_water": "Never",
            "water_level_ok": True,
            "temperature": "N/A",
            "humidity": "N/A",
            "uptime": "0m",
            "manual_water_requested": False,
        }

        # Set up scheduled jobs
        self._setup_schedules()

        # Signal handlers
        signal.signal(signal.SIGINT, self._shutdown)
        signal.signal(signal.SIGTERM, self._shutdown)

    def _setup_schedules(self):
        """Configure scheduled tasks."""
        cfg = self.config

        # Water: daily at configured time
        if cfg["water"]["enabled"]:
            schedule.every().day.at(cfg["water"]["schedule"]).do(self.do_water)
            log.info(f"Water scheduled daily at {cfg['water']['schedule']}")

        # Sensor check: every N seconds
        if cfg["sensors"]["bme280_enabled"]:
            interval = cfg["sensors"]["check_interval_seconds"]
            schedule.every(interval).seconds.do(self.do_sensor_check)
            log.info(f"Sensor checks every {interval}s")

        # Daily status report at 10pm
        schedule.every().day.at("22:00").do(self.do_daily_report)

    def do_water(self):
        """Execute water refill."""
        log.info("=== Water refill triggered ===")

        # Check reservoir first
        if not self.hardware.check_water_level():
            self.state["water_level_ok"] = False
            self.notifier.notify(
                "⚠️ <b>Water reservoir LOW!</b>\nSkipping refill. Please ask someone to refill.",
                "water/alert", {"level": "low"}
            )
            return

        self.hardware.pump_water(self.config["water"]["pump_duration_seconds"])
        now = datetime.now().strftime("%Y-%m-%d %H:%M")
        self.state["last_water"] = now
        self.state["water_level_ok"] = True

        self.notifier.notify(
            f"💧 Water refilled at {now}",
            "water/status", {"action": "refilled", "time": now}
        )

    def do_sensor_check(self):
        """Read sensors and check thresholds."""
        reading = self.sensors.read()
        if reading:
            if reading.get("temperature_f"):
                self.state["temperature"] = f"{reading['temperature_f']:.1f}°F"
            if reading.get("humidity"):
                self.state["humidity"] = f"{reading['humidity']:.0f}%"

            # Check thresholds
            alerts = self.sensors.check_thresholds(reading)
            for alert in alerts:
                self.notifier.notify(alert, "sensors/alert", {"alert": alert})

            # Publish sensor data via MQTT
            self.notifier.publish_mqtt("sensors/data", reading)

        # Also check water level
        water_ok = self.hardware.check_water_level()
        if not water_ok and self.state["water_level_ok"]:
            # Transition from OK to LOW
            self.state["water_level_ok"] = False
            self.notifier.notify(
                "⚠️ <b>Water reservoir is getting LOW!</b>\nPlease arrange a refill.",
                "water/alert", {"level": "low"}
            )
        self.state["water_level_ok"] = water_ok

    def do_daily_report(self):
        """Send daily status summary."""
        uptime = datetime.now() - self.start_time
        hours = int(uptime.total_seconds() // 3600)
        days = hours // 24

        report = (
            "📊 <b>Daily Gecko Report</b>\n\n"
            f"💧 Last water: {self.state['last_water']}\n"
            f"🌡 Temp: {self.state['temperature']}\n"
            f"💧 Humidity: {self.state['humidity']}\n"
            f"🪣 Reservoir: {'✅ OK' if self.state['water_level_ok'] else '⚠️ LOW'}\n"
            f"🦗 Feeding: check cameras (Petbank managed)\n"
            f"⏱ Uptime: {days}d {hours % 24}h"
        )
        self.notifier.notify(report, "status/daily", self.state)

    def run(self):
        """Main run loop."""
        log.info("🦎 Gecko Automation starting...")
        self.notifier.notify("🦎 Gecko Automation is online!")

        # Start web server in background thread
        if self.config["web"]["enabled"] and FLASK_AVAILABLE:
            app = create_web_app(self.state)
            web_thread = threading.Thread(
                target=app.run,
                kwargs={
                    "host": self.config["web"]["host"],
                    "port": self.config["web"]["port"],
                    "debug": False,
                    "use_reloader": False
                },
                daemon=True
            )
            web_thread.start()
            log.info(f"Web dashboard at http://0.0.0.0:{self.config['web']['port']}")

        # Main loop
        while self.running:
            schedule.run_pending()

            # Check for manual triggers (from web API)
            if self.state.get("manual_water_requested"):
                self.state["manual_water_requested"] = False
                self.do_water()

            # Update uptime
            uptime = datetime.now() - self.start_time
            hours = int(uptime.total_seconds() // 3600)
            days = hours // 24
            self.state["uptime"] = f"{days}d {hours % 24}h {int((uptime.total_seconds() % 3600) // 60)}m"

            time.sleep(1)

    def _shutdown(self, signum, frame):
        """Graceful shutdown."""
        log.info("Shutting down...")
        self.running = False
        self.hardware.cleanup()
        self.notifier.notify("🦎 Gecko Automation shutting down")
        sys.exit(0)


if __name__ == "__main__":
    app = GeckoAutomation()
    app.run()
