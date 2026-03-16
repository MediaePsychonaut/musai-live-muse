# Protocol: [ZENITH-STRESS-PERFORMANCE]

**Objective**: To validate the absolute stability of the Sanctuary under multi-agent pressure and verify the zero-bleed irrigation logic in a live performance environment.

## 📋 Pre-Test Requirements
- Device at >30% battery.
- High-speed Wi-Fi or 5G connection.
- Instrument/Mic calibrated at -12dB headroom.

## 🧪 Phase 1: Sequential Pressure Test (The Director's Drill)
1.  **Handshake**: Start a session and connect to the Muse.
2.  **Burst Trigger**: Ask the Muse the following in rapid succession without waiting for response:
    - "Set metronome to 120."
    - "Activate the drone in G."
    - "What is my current pitch?"
3.  **Observation**: 
    - [ ] Commands must execute sequentially with the 50ms pulse gap.
    - [ ] No `1011` or `1007` WebSocket disconnects.
    - [ ] Hardware state remains stable (no stuttering).

## 🧪 Phase 2: Zero-Bleed Irrigation Verification 
1.  **Induce Response**: Ask the Muse a long technical question (e.g., "Explain the circle of fifths in detail").
2.  **Barge-In**: Interrupt the Muse mid-sentence by playing a loud, clear note.
3.  **Observation**:
    - [ ] The vocal buffer must purge **instantaneously**.
    - [ ] Zero "Echo" or overlapping audio fragments from the previous turn.
    - [ ] AI immediately acknowledges the interruption or transitions to listening.

## 🧪 Phase 3: Holographic Lock-In Audit
1.  **Precision Tuning**: Hum or play the note **G3** slowly.
2.  **Approach**: Watch the Tuner cents deviation drift towards 0.
3.  **Observation**:
    - [ ] At $< 15$ cents, the main note label opacity increases to 0.9.
    - [ ] At $< 5$ cents, the **30 blurRadius Neon Glow** must trigger with 1.0 opacity.
    - [ ] Background "♭" and "♯" symbols remain at 0.45 opacity for clarity.

## 🧪 Phase 4: Mobile Telemetry Continuity
1.  **Platform Shift**: Deploy to Android/iOS device.
2.  **Telemetry Sync**: Play for 5 minutes with significant volume peaks (>0.05).
3.  **Audit**:
    - [ ] Check `MUSE_LAB_ECHO` in the developer console.
    - [ ] Root/Verify local file storage: `ApplicationDocumentsDirectory/LAB_LOG_SESSION.txt`.
    - [ ] Ensure all tool executions (TOOL_EXEC) are logged with arguments.

**PASS CRITERIA**: Zero protocol crashes, zero audio bleed, and sustained visual "Lock-In" at peak precision. 🏁🦉🦅🦇🏁
