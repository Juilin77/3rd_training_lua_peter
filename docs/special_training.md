# Special Training

![Special Training Menu](../screenshots/special_training_menu.png)

Focused training tools for specific SF3 mechanics. Select a mode from **Special Training → Mode** and close the menu to activate.

| Option | Description |
|--------|-------------|
| Mode | Training mode: None / Parry / Charge / Hyakuretsu Kyaku / Juggle / Tech Throw / 720 |
| Follow Character | Gauge follows P1's on-screen position. Grayed out in None, Juggle, Tech Throw, and 720 modes. |

---

## Parry Mode

![Parry Mode](../screenshots/special_training_parry.png)

Shows real-time timing gauges for all four parry types. Each gauge has two bars:
- **Blue bar** — validity window (the frame window where a parry input is accepted)
- **Orange bar** — cooldown window (frames before the next parry can be attempted)
- **Green number** — delta: how many frames early (positive) or late (negative) the parry input was

| Option | Description |
|--------|-------------|
| Forward Parry Helper | Show timing gauge for forward parry. |
| Down Parry Helper | Show timing gauge for down parry. |
| Air Parry Helper | Show timing gauge for air parry. |
| Anti-Air Parry Helper | Show timing gauge for anti-air parry. |
| Follow Character | Gauge follows P1's on-screen position. |

---

## Charge Mode

![Charge Mode](../screenshots/special_training_charge.png)

Shows charge timers for held-input special moves (e.g. Remy's LoV, Urien's Headbutt). Each gauge fills as you hold the required direction. The number on the right shows remaining frames to complete the charge.

| Option | Description |
|--------|-------------|
| Display Overcharge | Highlight when charge exceeds the minimum required (overcharge indicator). |
| Follow Character | Gauge follows P1's on-screen position. |

---

## Hyakuretsu Kyaku Mode (Chun-Li only)

![Hyakuretsu Kyaku Mode](../screenshots/special_training_hyakuretsu.png)

Tracks rapid kick button presses for Chun-Li's Hyakuretsu Kyaku. Shows input count for LK / MK / HK and a reset timer bar. The reset timer shows how long until the kick count resets if no button is pressed.

---

## Juggle Mode

![Juggle Mode](../screenshots/special_training_juggle.png)

Displays the dummy's remaining **air hitstun** (juggle frames) as a gauge with tick marks. Each tick corresponds to a juggle decay threshold — once the gauge drops past a tick, the next hit may not connect. Use this to find the optimal timing and limit for air combos.

---

## Tech Throw Mode

![Tech Throw Mode](../screenshots/special_training_techthrow.png)

Shows a timing gauge when you are grabbed. Input **LP+LK** within the green window to tech (escape) the throw.

- **Green bar** — 5-frame tech window (input LP+LK here)
- **Orange bar** — Fwd/down parry validity (parry active = cannot tech throw)
- **Delta marker** — shows how many frames early or late your LP+LK input was
- **Result text** — Success (green) / Too Early / Too Late / Parry Active (red)

---

## 720 Mode (Hugo only)

![720 Mode](../screenshots/special_training_720.png)

Detects Hugo's 720° rotation input using SF3's 11-frame window. Shows an input display and result feedback.

- **Result text** — 720! (green, success) / Too Late / Wrong Button
- **Orange bar** — 11-frame input window
- **Input squares** — direction inputs captured during the rotation
