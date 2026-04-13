# 🦎 Gecko Automation

Automated care system for Jack (leopard gecko) during a 7-week family vacation. Provides scheduled feeding and fresh water without daily human intervention.

## Overview

- **Water system**: Peristaltic pump on a daily schedule refills the water dish, overflow drains into substrate/humid hide
- **Feeding system**: Mealworm hopper kept cool in a mini fridge, servo-driven gate dispenses portions 2-3x per week
- **Monitoring**: Camera feeds + sensor data (temp/humidity) with alerts via Home Assistant → Telegram
- **Controller**: Raspberry Pi (Zero 2 W or any spare Pi) running Python

## Architecture

```
┌─────────────┐     ┌──────────────┐
│  Water       │     │  Mealworm    │
│  Reservoir   │     │  Hopper      │
│  (2-3L)      │     │  (in mini    │
│              │     │   fridge)    │
└──────┬───────┘     └──────┬───────┘
       │                     │
  Peristaltic            Servo gate
    pump                 + vibe motor
       │                     │
       ▼                     ▼
┌──────────────────────────────────────┐
│           Terrarium                  │
│  ┌───────────┐    ┌──────────────┐   │
│  │ Water dish │    │ Feeding dish │   │
│  │ (overflow  │    │ (smooth      │   │
│  │  → humid   │    │  sided)      │   │
│  │  hide)     │    │              │   │
│  └───────────┘    └──────────────┘   │
│                                      │
│  BME280 sensor (temp/humidity)       │
│  Camera(s)                           │
└──────────────────────────────────────┘
       │
  ┌────┴────┐
  │ Raspberry│──── WiFi ────→ Home Assistant
  │   Pi     │                → Telegram alerts
  └─────────┘
```

## Parts List

### Controller
| Part | Est. Cost |
|------|-----------|
| Raspberry Pi Zero 2 W (or any spare Pi) | ~$15 |
| MicroSD card (16GB+) | ~$5-8 |
| USB micro power supply (5V 2.5A) | ~$8 |

### Water System
| Part | Est. Cost |
|------|-----------|
| Peristaltic pump, 12V, food-safe silicone tubing | ~$8-12 |
| Extra silicone tubing (3mm ID, food-grade) | ~$5-7 |
| 12V 2A DC power supply | ~$5-8 |
| Water level float switch (for reservoir) | ~$3-5 |

### Mealworm Feeder
| Part | Est. Cost |
|------|-----------|
| Mini fridge (4-6L thermoelectric) | ~$25-35 |
| MG996R servo motor | ~$6-8 |
| Vibration motor (3V coin type) | ~$2-3 |

### Electronics
| Part | Est. Cost |
|------|-----------|
| 2-channel 5V relay module | ~$4-5 |
| IRF520 MOSFET module | ~$3-4 |
| BME280 temp/humidity sensor (I2C) | ~$4-6 |
| Jumper wires + breadboard | ~$5-8 |

### Hardware / DIY
| Part | Est. Cost |
|------|-----------|
| Feeding dish (smooth ceramic ramekin) | ~$3 |
| 3D printed hopper (see `hopper/`) | filament |
| Water reservoir (2-3L bottle) | free |

**Estimated total: $85-130**

## 3D Printed Hopper

The `hopper/mealworm_hopper.scad` file contains a parametric OpenSCAD design with:

- Cylindrical hopper body (60mm × 100mm) for mealworms + bran
- Funnel narrowing to servo gate
- Rotating disc gate with portioning notch (MG996R servo)
- Vibration motor mount to prevent bridging
- Angled dispensing chute (45°) for gravity drop
- Ventilated snap-on lid

**Print settings:** 0.2mm layer, 15-20% infill, PLA or PETG, no supports needed.

Open in OpenSCAD → uncomment individual parts → export STL for printing.

## Software

`src/gecko_automation.py` — Main controller script

- Scheduled water dispensing (daily)
- Scheduled feeding (2-3x per week)
- BME280 sensor monitoring
- Float switch monitoring
- MQTT integration for Home Assistant
- Telegram alerts for events and anomalies
- Web dashboard for remote status
- Configurable via `config.json`

### Setup on Pi

```bash
# Clone the repo
git clone https://github.com/agentjuice/gecko-automation.git
cd gecko-automation

# Install dependencies
pip3 install RPi.GPIO paho-mqtt smbus2 flask schedule

# Copy and edit config
cp config.example.json config.json
nano config.json

# Run
python3 src/gecko_automation.py

# Or install as systemd service
sudo cp gecko-automation.service /etc/systemd/system/
sudo systemctl enable gecko-automation
sudo systemctl start gecko-automation
```

## Schedule

| Event | Frequency | Default Time |
|-------|-----------|-------------|
| Water refill | Daily | 8:00 PM |
| Mealworm feeding | Mon/Wed/Fri | 9:00 PM |
| Sensor check | Every 5 min | — |
| Status report | Daily | 10:00 PM |

## Timeline

- **April-May 2026**: Order parts, build hardware, develop software
- **June 2026**: Full dry run (2+ weeks with system running while home)
- **July-August 2026**: Deploy for real during Malta trip

## Monitoring

The system sends Telegram alerts for:
- ✅ Feeding dispensed successfully
- ✅ Water refilled
- ⚠️ Reservoir water low
- ⚠️ Temperature out of range
- ⚠️ Humidity out of range
- 🚨 Sensor read failure
- 🚨 Servo/pump malfunction detected

## License

MIT
