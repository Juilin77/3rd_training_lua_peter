# Dummy

![Dummy](../screenshots/dummy.png)

Configure how the CPU-controlled dummy behaves during training. Set its default stance, blocking style, throw tech responses, and counter-attack options.

| Option | Description |
|--------|-------------|
| Pose | Default stance for the dummy: Normal, Crouching, Forward Jump, Neutral Jump, Back Jump, Super Fwd Jump, Super Jump, Super Back Jump, Forward Dash, or Back Dash. |
| Blocking Style | How the dummy defends: block (normal guard), parry (forward parry), or red parry. Enables "Hits before Red Parry" when set to red parry. |
| Hits before Red Parry | Number of hits received before the dummy performs a red parry. Only active when Blocking Style is set to red parry. |
| Blocking Mode | When the dummy triggers its blocking behavior, only active when Blocking Style is set to block: never, always, meaty/oki, randomly, or combo only. See "Blocking Mode" below for details on meaty/oki and combo only. |
| Tech Throws | Whether the dummy attempts to escape throws: never, always, or randomly. |
| Counter-Attack Move | Stick motion the dummy performs when counter-attacking: QCF, QCB, HCF, HCB, DPF, DPB, HCharge, VCharge, 360, DQCF, 720, forward, back, down, jump, super jump, forward jump, forward super jump, back jump, back super jump, forward dash, back dash, guard jump, Shun Goku Satsu, Kongou Kokuretsu Zan. |
| Counter-Attack Action | Button the dummy presses for its counter-attack. Set to "recording" to replay a recorded slot instead. |
| Fast Wake Up | Whether the dummy quick-rises after a knockdown: never, always, or randomly. |

---

## Blocking Mode

Only active when Blocking Style is set to block.

| Mode | Behavior |
|------|----------|
| Never | The dummy never blocks. |
| Always | The dummy blocks every hit it predicts. |
| Meaty/Oki | The dummy fails to block a hit that lands before it has been idle for 20 frames, useful for practicing wakeup meaties, tick throws, and other setups thrown right after a knockdown or the end of the previous exchange. |
| Random | Each predicted hit has a 50% chance of being blocked. |
| Combo Only | The first hit of each fresh engagement always connects, since the dummy won't block it. Everything after behaves like Always, so a true frame-tight combo naturally connects because the dummy is still in hitstun, while a hit with a gap gets blocked normally. |
