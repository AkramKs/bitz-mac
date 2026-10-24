# Contract: Rive State Machine (`BitzStateMachine`)

**Mission**: `bitz-macos-mascot-01M5R2H1`  
**File Asset**: `bitz_mascot.riv`  
**State Machine Name**: `BitzStateMachine`

---

## 1. Input Parameters Contract

The `bitz_mascot.riv` file and `BitzRiveControllable` bridge MUST expose the following exact input names and types:

| Input Name | Rive Type | Swift Type | Valid Values / Range | Behavioral Effect |
| :--- | :--- | :--- | :--- | :--- |
| `speedMultiplier` | `Number` | `Float` | `0.0` to `2.5` | Multiplies the playback speed of Bitz's floating/bobbing loop and ear/tail oscillation. |
| `visorColor` | `Number` | `Float` | `0.0`, `1.0`, `2.0`, `3.0` | `0.0` = Cyan (Balanced), `1.0` = Magenta (Super Charged), `2.0` = Amber (Overworked), `3.0` = Red (Overheating). |
| `isStandby` | `Boolean` | `Bool` | `true`, `false` | When `true`, collapses Bitz into standby loaf posture and renders `"ZZZ"` on the LED visor. |
| `isGlitching` | `Boolean` | `Bool` | `true`, `false` | When `true`, plays rapid glitch/jitter animation with sweat drops and `"! !"` visor alert. |
| `triggerPet` | `Trigger` | `Void` (pulse) | Pulse event | Fires a happy bounce and `"^ ^"` visor reaction. |

---

## 2. State-to-Input Mapping Contract

Every transition of `WellnessPointEngine.currentState` MUST synchronize the `BitzStateMachine` inputs as follows:

| `BitzState` | `speedMultiplier` | `visorColor` | `isStandby` | `isGlitching` | Overlay Speech Bubble |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `.superCharged` (`80.0...100.0`) | `2.0` | `1.0` (Magenta) | `false` | `false` | Hidden |
| `.balanced` (`40.0..<80.0`) | `1.0` | `0.0` (Cyan) | `false` | `false` | Hidden |
| `.overworked` (`15.0..<40.0`) | `0.4` | `2.0` (Amber) | `false` | `false` | Hidden |
| `.burnout` (`< 15.0`) | `0.0` | *(preserved / dimmed)* | `true` | `false` | Hidden |
| `.overheating` (`> 80°C` / critical thermal) | *(preserved)* | `3.0` (Red) | `false` | `true` | `"SYSTEM HOT! > <"` (Red Capsule) |
