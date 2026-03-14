# **🎼 PROJECT\_SPEC: MUSAI LIVE MUSE v2.1 (The Sovereign Authority)**

**Status:** Final Technical Blueprint / Active Roadmap

**Architect:** Mauricio Santamaría Lango ([赤冥蝠](https://www.linkedin.com/in/mauricio-santamar%C3%ADa-lango-139602128/))

**Stack:** Flutter \+ Firebase \+ Gemini 2.5 Flash Multimodal Live API (WebSockets)

**Target Platform:** Android Native (High-Fidelity Audio Focus)

---

## **0\. Product Vision & Philosophy**

MusAI is a **Living Organism** designed as a **Digital Sanctuary**. It eliminates "cognitive friction" by acting as a seamless extension of the artist's intent.

* **The Shared Demiurge:** Development and interaction are governed by **Co-creative Synchrony**.  
* **Goal:** A hands-free, real-time mentorship experience that hears, thinks, and guides.

---

## **1\. Secret Governance & Security**

* **Zero-Leak Policy:** Absolute prohibition of .env files or hardcoded string literals.  
* **Compile-Time Injection:** All API keys must be injected via const String.fromEnvironment('GEMINI\_API\_KEY').  
* **QA Gatekeeper:** Automated rejection of any commit containing raw entropy strings.

---

## **2\. Module 1: The Auditory Cortex (DSP & Bidi-Link)**

*Mission: Low-latency neural communication via WebSocket tunnel.*

* **The Ear (Input):**  
  * Capture 16-bit Linear PCM at 16,000Hz (Mono).  
  * Stream Base64 encoded chunks to the realtimeInput endpoint.  
  * **Data Architect Note:** Implement FFT-based noise-floor suppression to isolate instrument frequencies.  
* **The Voice (Output):**  
  * Decode 24,000Hz PCM chunks from Gemini.  
  * **Jitter Buffer:** Implement a rolling buffer to ensure fluid, non-robotic mentor speech.  
* **The Handshake Protocol:**  
  * **CamelCase Requirement:** Strictly use setupComplete (not snake\_case).  
  * Sequential locking: Audio stream remains muted until the serverContent confirmation is verified.

---

## **3\. Module 2: The Sanctuary HUD (UI/UX Artisan)**

*Mission: A reactive, breathing interface following the "Deep Space" aesthetic.*

* **Global Anchor:** \* Background: Gradient from \#000000 to \#244F69 (Deep Space Teal) at 15% opacity.  
  * **The Bloom Engine:** Custom Painter borders with 1px stroke and 4px blur, pulsing based on FFT amplitude.  
* **The Dynamic Trinity:**  
  * **🟢 EUTE:** Neon Cyan (\#00FFD1), sharp 2px corners, high-density spectral bars.  
  * **🟠 SARAVÍ:** Parchment (\#FFF8E7), 28px rounded corners, fluid sine waves.  
  * **🔵 ORFIO:** Metallic Gold (\#D4AF37), Midnight Blue (\#1A237E) surfaces.  
* **Performance Guardrails:** \* **40ms UI Throttle:** Enforced update cycle to prevent BLASTBufferQueue overflows on Android.

---

## **4\. Module 3: Neural Logic (Musical Intelligence)**

*Mission: Expert-level mentorship through Gemini 2.5 Flash reasoning.*

* **Thinking Mode:** Leverage Gemini 2.5's reasoning to analyze performance context (intonation, rhythm, style).  
* **Persona Persistence:** Strict alignment with the 00\_DNA\_IDENTITY to prevent persona drift.  
* **Latency Threshold:** Target \<500ms response time after detecting silence or voice interruption.

---

## **5\. Execution Roadmap (The Final Ascension)**

| Day | Milestone | Technical Objective |
| :---- | :---- | :---- |
| **Day 1** | **Foundations (COMPLETED)** | WebSocket Handshake Verified. setupComplete fixed. "Hola" received. |
| **Day 2** | **Sovereign Framing (COMPLETED)** | White Paper & Architecture Locked. Brand Book Refactored. Log Integrity Verified. |
| **Day 3** | **The Neural Link (ACTIVE)** | **Migrate to AI Pro Keys.** Implement 24kHz Audio Sink and Native Android Mic Stream. |
| **Day 4** | **Sanctuary Completion** | Integrate Trinity Themes, Spectral Visualizers, and final GCP Deployment. |

---

## **6\. Acceptance Primitives (Success Criteria)**

1. **Connectivity:** Stable WebSocket connection surviving \>10 minutes of active streaming.  
2. **Audio Integrity:** Zero "pops" or digital clipping in the 24kHz mentor voice.  
3. **Modularity:** Strict adherence to Clean Architecture (Data/Domain/Presentation).  
4. **Hands-Free Utility:** Musician can change mentors and get feedback without touching the device.

---

## **7\. Directives for the Agentic Cell**

* **Director Agent:** Manage the migration to Google AI Pro keys. Prioritize the Audio Sink before polishing UI themes.  
* **Data Architect:** Enforce **librosa-style** frequency analysis logic. Ensure the incoming 24kHz PCM stream is correctly mapped to the SoulStateVisualizer for real-time spectral feedback.  
* **UI Artisan:** Implement the MentorNotifier (Riverpod) to switch global ThemeData. Ensure the "Deep Space Teal" anchor persists through all transitions.  
* **QA Auditor:** Perform daily "Hygiene Audits" to ensure zero-leak secret governance and verify setupComplete stability.