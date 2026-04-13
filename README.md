# 🦎 Gecko Automation

Automated care system for Jack (leopard gecko, ~50g, ~1.5 years old) during a 7-week family vacation (July–August 2026). Provides scheduled feeding and fresh water without daily human intervention.

## Overview

- **Feeding**: Petbank carousel fish feeder inside a mini fridge — keeps mealworms dormant at ~55°F, dispenses pre-portioned meals on schedule through a hole in the fridge bottom into the terrarium
- **Water**: Peristaltic pump on a daily schedule refills the water dish, overflow drains into substrate/humid hide
- **Monitoring**: Camera feeds + sensor data (temp/humidity) with alerts via Telegram
- **Controller**: Raspberry Pi running Python (water pump + sensors only — feeder has its own timer)

## Architecture

```
┌─────────────────────────────┐
│  Mini Fridge (~55°F)        │  ← elevated above enclosure
│                             │
│  ┌───────────────────────┐  │
│  │  Petbank Carousel     │  │
│  │  Feeder (×2)          │  │
│  │  16 compartments each │  │
│  │  USB-C powered        │  │
│  └──────────┬────────────┘  │
│             │               │
│  ┌──────────▼────────────┐  │
│  │  Dispensing hole       │  │  ← also provides ventilation
│  │  (bottom of fridge)    │  │
│  └──────────┬────────────┘  │
└─────────────┼───────────────┘
              │ gravity
              ▼
┌──────────────────────────────────────┐
│           Terrarium                  │
│                                      │
│  ┌───────────┐    ┌──────────────┐   │
│  │ Water dish │    │ Feeding dish │   │
│  │ (overflow  │    │ (smooth      │   │
│  │  → humid   │    │  ceramic)    │   │
│  │  hide)     │    │              │   │
│  └───────────┘    └──────────────┘   │
│                                      │
│  + ~12 small crickets (loose)        │
│  + BME280 sensor (temp/humidity)     │
│  + Camera(s)                         │
└──────────────────────────────────────┘

Water Reservoir (2-3L)
       │
  Peristaltic pump ← Raspberry Pi (GPIO)
       │                    │
       ▼                    ├── BME280 sensor
  Water dish                ├── Float switch (reservoir)
                            ├── WiFi → Telegram alerts
                            └── Web dashboard
```

## Feeding Strategy

### Mealworms (primary — automated)
- 2× Petbank carousel feeders inside a mini fridge
- Each feeder: 16 compartments, 15 usable meals, ~5-8 mealworms per compartment
- Fridge keeps mealworms at ~55°F = dormant, won't pupate (at room temp 75°F they pupate within days)
- Fridge elevated above enclosure, hole drilled in bottom aligned with feeding dish
- Petbank dispenses on schedule → mealworms drop through hole → into dish
- 2 feeders × 15 meals = 30 meals, need 21 for 7 weeks at 3×/week — plenty of buffer
- Ventilation holes drilled in Petbank lid (1-2mm, or mesh-covered) for mealworm air supply
- Dispensing hole in fridge bottom doubles as ventilation (cold air sinks, warm air enters via door gaps)

### Crickets (supplemental — passive)
- ~12 small (1/4") crickets released in terrarium before departure
- Hide in crevices, emerge naturally for Jack to hunt
- Cricket food/gel cubes tucked in a corner to keep them alive longer
- Not counted as primary nutrition — just variety

### What NOT to use
- Waxworms: get hunted by other insects in the enclosure
- Dried mealworms: Jack may not recognize them as food (no movement)

## Parts List

### Feeding System
| Part | Est. Cost | Notes |
|------|-----------|-------|
| Petbank CY-009 carousel feeder (×2) | ~$40-50 | 16 compartments each, USB-C powered |
| Mini fridge (4-6L thermoelectric) | ~$25-35 | "Skincare fridge" type, keeps ~55°F |

### Water System
| Part | Est. Cost | Notes |
|------|-----------|-------|
| Peristaltic pump, 12V, food-safe | ~$8-12 | Silicone tubing, ~100mL/min |
| Silicone tubing (3mm ID, food-grade) | ~$5-7 | Reservoir → water dish |
| 12V 2A DC power supply | ~$5-8 | Powers pump |
| Water level float switch | ~$3-5 | In reservoir, alerts when low |

### Controller & Sensors
| Part | Est. Cost | Notes |
|------|-----------|-------|
| Raspberry Pi (Zero 2 W or any spare) | ~$15 | Or use one you already have |
| MicroSD card (16GB+) | ~$5-8 | If needed |
| 2-channel 5V relay module | ~$4-5 | Switches 12V pump |
| BME280 temp/humidity sensor | ~$4-6 | I2C, mount in enclosure |
| Jumper wires | ~$3-5 | If needed |

### Hardware / DIY
| Part | Est. Cost | Notes |
|------|-----------|-------|
| Feeding dish (smooth ceramic ramekin) | ~$3 | Mealworms can't climb out |
| Water reservoir (2-3L bottle) | free | From kitchen |
| Shelf/stand for fridge | varies | Elevate above enclosure |
| Funnel/collar for fridge hole | ~$2 | PVC ring or 3D printed, prevents worms missing the hole |

**Estimated total: $65-100** (less if you have a Pi and misc parts)

## Software

`src/gecko_automation.py` — Raspberry Pi controller for water + monitoring only

- Scheduled water dispensing (daily, configurable time)
- BME280 sensor monitoring (temp/humidity with threshold alerts)
- Float switch monitoring (reservoir low alert)
- Telegram alerts for events and anomalies
- Web dashboard for remote status
- Configurable via `config.json`

Note: The Petbank feeders have their own built-in timer — no Pi integration needed for feeding.

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

| Event | Frequency | Default Time | Controller |
|-------|-----------|-------------|------------|
| Mealworm feeding | 3×/week | Configured on Petbank | Petbank timer |
| Water refill | Daily | 8:00 PM | Raspberry Pi |
| Sensor check | Every 5 min | — | Raspberry Pi |
| Status report | Daily | 10:00 PM | Raspberry Pi |

## Build & Test Timeline

- **April 2026**: Order parts (Petbank feeders, mini fridge, pump, Pi accessories)
- **May 2026**: Assemble hardware, drill fridge, set up Pi software
- **June 2026**: Full dry run — 2+ weeks with system running while home
  - Verify mealworms stay alive and dormant in fridge
  - Verify Petbank motor works reliably at ~55°F
  - Verify mealworms drop cleanly through fridge hole into dish
  - Calibrate water pump duration (target ~20-30mL/day)
  - Confirm Telegram alerts working
- **July–August 2026**: Deploy for real during Malta trip

## Pre-Departure Checklist

- [ ] Load both Petbank feeders with mealworms + bran (5-8 per compartment)
- [ ] Verify Petbank schedules are set and staggered
- [ ] Fill water reservoir (2-3L)
- [ ] Verify Pi is running, pump tested, sensors reading
- [ ] Release ~12 small crickets in terrarium
- [ ] Add cricket food/gel cubes
- [ ] Plug in Petbank feeders via USB-C (don't rely on battery)
- [ ] Confirm camera feeds are accessible remotely
- [ ] Send test Telegram alert
- [ ] Brief emergency contact (friend) on what to do if alerted

## Monitoring & Alerts

The system sends Telegram alerts for:
- ✅ Water refilled
- ⚠️ Reservoir water low
- ⚠️ Temperature out of range (< 70°F or > 90°F)
- ⚠️ Humidity out of range (< 20% or > 50%)
- 🚨 Sensor read failure
- 📊 Daily status summary

## Emergency Plan

If something goes wrong that requires human intervention:
1. Telegram alert fires → Daniel reviews camera feeds remotely
2. If action needed → contact local friend with house access
3. Friend has instructions for: refilling water, resetting feeders, checking on Jack

## License

MIT
