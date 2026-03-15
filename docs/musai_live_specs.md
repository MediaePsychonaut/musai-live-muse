# **🎼 PROJECT\_SPEC: MUSAI LIVE MUSE v3.0 (The Polymorphic Authority)**

**Status:** Final Technical Blueprint / Active Roadmap

**Architect:** Mauricio Santamaría Lango ([赤冥蝠](https://www.linkedin.com/in/mauricio-santamar%C3%ADa-lango-139602128/))

**Stack:** Flutter \+ Firebase \+ Gemini Multimodal Live API (Hybrid v1α/v1β)

**Target Platform:** Android Native (Sovereign High-Fidelity Audio)

---

## **0\. Product Vision & Philosophy**

MusAI is a **Living Organism** designed as a **Digital Sanctuary**. It eliminates "cognitive friction" by acting as a seamless extension of the artist's intent.

* **The Shared Demiurge:** Development and interaction are governed by **Co-creative Synchrony**.  
* **Goal:** A hands-free, real-time mentorship experience that hears, thinks, and guides.  
* **Autonomy Transition:** Moving from a simple chat interface to a professional-grade, pulse-aware tool.

---

## **1\. Secret Governance & Security**

* **Zero-Leak Policy:** Absolute prohibition of .env files or hardcoded string literals.  
* **Compile-Time Injection:** All API keys must be injected via const String.fromEnvironment('GEMINI\_API\_KEY').  
* **QA Gatekeeper:** Automated rejection of any commit containing raw entropy strings.

---

## **2\. Module 1: The Auditory Cortex (DSP & Bidi-Link)**

*Mission: Low-latency neural communication via Polymorphic WebSocket tunnel.*

* **The Ear (Input):**  
  * Capture 16-bit Linear PCM at 16,000Hz (Mono).  
  * **Mono Guard:** Surgical downmixing to 1-channel mono to prevent 1007 protocol violations.  
* **The Voice (Output):**  
  * **Native Audio Sink:** Direct 24,000Hz PCM push to Android AudioTrack via MethodChannel (MODE\_STREAM).  
  * **Sovereign Jitter Management:** Increased native hardware buffer (8x multiplier) to neutralize network variance.  
* **Polymorphic Protocol Architecture:**  
  * **Hybrid Parser:** Version-agnostic listener supporting both setup\_complete (snake\_case) and setupComplete (camelCase) frames.  
  * **Gemini 2.0 (v1alpha):** Enforces snake\_case keys and experimental voice configurations.  
  * **Gemini 2.5 (v1beta):** Enforces camelCase keys and the high-fidelity Aoede voice config.

---

## **3\. Module 2: The Sanctuary HUD (UI/UX Artisan)**

*Mission: A reactive, breathing interface following the "Deep Space" aesthetic.*

* **Global Anchor:**  
  * Background: Gradient from \#000000 to \#244F69 (Deep Space Teal) at 15% opacity.  
  * **The Bloom Engine:** Custom Painter borders pulsing based on FFT amplitude.  
* **Display Sovereignty:**  
  * **60ms UI Throttle:** Precise update cadence to eliminate BLASTBufferQueue overflows on Android hardware.  
  * **Repaint Boundaries:** Visualizer isolation to prevent high-frequency bloom updates from triggering full HUD rebuilds.  
* **Dynamic Trinity & Engine Toggle:**  
  * **🟢 EUTE:** Neon Cyan (\#00FFD1), technical spectral bars.  
  * **🟠 SARAVÍ:** Parchment (\#FFF8E7), fluid sine waves.  
  * **Engine Switcher:** Micro-toggle UI to pivot between Gen 2.0 reasoning and 2.5 native speed on the fly.

---

## **4\. Module 3: Neural Logic (Musical Intelligence)**

*Mission: Expert-level mentorship through Imperative Reasoning.*

* **Imperative Identity Lock:** Purge "reasoning" language from system instructions. Mentors act directly on the acoustic stream without self-explanation.  
* **Cognitive Proactivity:** The **"Active Observer"** protocol. AI treats spectral peaks (196Hz–659Hz) as the Architect's voice, interrupting with feedback unprompted.  
* **Metadata Bridge (Phase 5):** Future injection of FFT pitch data and metronome timestamps as metadata to eliminate AI hallucinations.

---

## **5\. Execution Roadmap (The Final Ascension)**

| Phase | Milestone | Technical Objective |
| :---- | :---- | :---- |
| **V1-V3** | **Foundations (COMPLETED)** | WebSocket Handshake, Native Audio Sink, and Initial Neural Link. |
| **V4.0** | **Identity Injection (COMPLETED)** | Dynamic Mentor switching and Protocol Polymorphism. |
| **V5.0** | **Restoration (ACTIVE)** | **Zombie Purge** (Lifecycle Hardening) and **Log Translucency** (Telemetry Parser). |
| **V6.0** | **The Pulse Engine** | **Oboe** native timing implementation and Temporal Sovereignty (Global Pulse). |

---

## **6\. Acceptance Primitives (Success Criteria)**

1. **Connectivity:** Stable WebSocket connection surviving \>10 minutes of active streaming.  
2. **Audio Integrity:** Gapless 24kHz playback with zero "pops" or digital clipping.  
3. **Lifecycle Sovereignty:** Zero "Bad state" errors when switching mentors or closing the session.  
4. **Telemetry:** Clean "Translucent Logs" showing real-time text transcription and audio packet sizes.

---

## **7\. Directives for the Agentic Cell**

* **Director Agent:** Manage the migration to the **Global Pulse Protocol**. Purge verbosity and enforce the **赤冥蝠** seal.  
* **Data Architect:** Implement the **Metadata Bridge**. Ensure local FFT data is correctly appended to the WebSocket realtimeInput.  
* **UI Artisan:** Optimize the **Bloom Engine** with RepaintBoundary and refine the **Secondary Bloom Pulse** for AI voice output.  
* **QA Auditor:** Perform "Passive Performance" audits to verify the AI's technical proactivity during violin practice.