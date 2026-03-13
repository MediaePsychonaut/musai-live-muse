# **🎼 PROJECT\_SPEC: MUSAI LIVE MUSE v1.2 (Sovereign Baseline)**

**Status:**  Technical Specification / Deep-Dive

**Project:** MusAI \- Real-Time Multimodal Musical Mentorship

**Sovereign:** 赤冥蝠 (Chì Míng Fú)

**Stack:** Flutter \+ Firebase \+ Gemini Multimodal Live API (WebSockets)

**Target Platform:** Flutter (Mobile) \+ Google Cloud (Vertex AI)

---

## **0\. Product Vision (Hackathon MVP)**

MusAI is not a utility; it is a **Living Organism**. The goal of this sprint is to demonstrate the capability of **Gemini 1.5 Pro (Multimodal Live API)** to act as a seamless extension of the musician’s memory and technique, processing live audio (violin/voice) and responding with expert feedback and harmonic accompaniment.

**Secret Governance:**

* **No-Hardcode Policy:** All API Keys must be accessed via `Platform.environment` or a secure `KeyChain/EncryptedSharedPrefs` wrapper.  
* **QA Gatekeeper:** Any commit containing a raw string resembling an API key will be automatically **REJECTED**.

---

## **1\. Deep-Dive: Module Architecture (The Ecosystem)**

### **Module 1: The Auditory Cortex (DSP & Live Stream Interface)**

* **Mission:** Capture and channel the bidirectional audio flow.  
* **WebSocket Protocol:** Establish a bidirectional connection using the `web_socket_channel` package.  
* **Audio Pipeline:**  
  * **Input:** Capture raw PCM 16-bit audio at a 16kHz sample rate (Mono).  
  * **Buffering:** Use a sliding window buffer of 2048 samples to minimize latency.  
  * **Noise Gate:** Implement a basic amplitude threshold filter to prevent background noise from triggering the Live API unnecessarily.  
* **Connection Resilience:**  
  * **Auto-Reconnect:** Implement an exponential backoff strategy (1s, 2s, 4s) for WebSocket drops.  
  * **State Persistence:** The `liveStreamProvider` must preserve the session ID and "Digital Twin" logs locally during reconnection attempts to prevent data loss.  
* **Barge-in Logic:** The UI must listen for a `model_turn` event from the API. If the user starts speaking or playing while the model is responding, the local audio player must immediately `stop()` and clear the output buffer.  
* **Ownership:** Data Agent (Backend/ADK) \+ UI Agent (Flutter Implementation).

### **Module 2: The Muse’s Consciousness (Agent Logic)**

Each Mentor is defined by a specific **System Instruction** passed during the initial WebSocket handshake. Integration of three operational modes via dynamic **Prompt Engineering**:

1. **PRACTICE MODE \- EUTE (The Technician):**  
   * *Prompt Constraint:* Focus exclusively on pitch (Hz) and rhythmic precision. Use short, corrective sentences.  
   * *Reference: Grounding in standard tuning (A=440Hz).*  
   * *Logic:* Intent recognition ("Play Schradieck 1 at 60 BPM").  
   * *Feedback:* Micro-segment correction of intonation and rhythm.  
2. **SCORE-DRIVEN MODE \- ORFIO (The Auditor):**  
   * For Score-Driven Mode, the first message sent over the WebSocket must be a `content_upload` containing the MusicXML/JSON text.  
   * System Instruction: "You are ORFIO. I am providing the score for \[Piece Name\]. Use this as the exclusive ground truth for pitch and dynamic analysis."  
   * *Prompt Constraint*: Analyze the performance against the provided MusicXML data. Focus on dynamics (p, mf, f) and phrasing.  
   * *Logic:* Grounding via **MusicXML/JSON**. Comparison of the "Map of Truth" vs. live performance.  
   * *Feedback:* Analysis of dynamics and adherence to the composer's intent.  
3. **HARMONIZED JAM MODE \- SARAVÍ (The Creative):**  
   * *Prompt Constraint:* Provide encouraging, metaphorical feedback. Focus on "flow" and "texture." Trigger harmonic responses.  
   * *Logic:* Analysis of key and mood within the first 15 seconds.  
   * *Output:* Generation of harmonic drones and basic counterpoints.  
4. **Graceful Degradation (Resilience Logic):**  
   * **Offline State:** If the WebSocket disconnects, the HUD must switch to a "Meditative State" (Local Metronome/Tuner) rather than crashing.  
   * **Latency Warning:** If RTT (Round Trip Time) exceeds 1000ms, the Muse should briefly shift to "EUTE" mode to provide short, low-bandwidth technical corrections until the connection stabilizes.  
5. **The Digital Twin (Autonomous Session Memory)**  
   * **Logic:** At the termination of a `Multimodal Live Session`, the Agent performs an internal "Self-Reflection" to generate a structured log.  
   * **Data Points:** \> \* **Content:** (e.g., "Schradieck No. 1", "Bach Partita No. 2").  
     1. **Technical Metrics:** Average BPM, Pitch Stability (%), and Total Duration.  
     2. **Mentor's Insight:** A 1-sentence summary of the user's progress for the "Second Brain."  
   * **Storage:** \> \* **Local:** SQLite (via `drift`) for instant dashboard updates.  
     1. **Cloud:** Firestore for cross-device "Grounding."

### **Module 3: Sanctuary HUD (UI/UX Sync)**

* **Mission:** Reflect the Muse’s "State of Soul" based on the **Brand Book**.  
* **State Management (Riverpod):**  
  * `mentorProvider`: Manages current theme and system prompts.  
  * `liveStreamProvider`: Manages WebSocket connection status and audio stream lifecycle.  
  * `analysisProvider`: Stores real-time metrics (Pitch, Tempo) for the visualizer.  
* **Visualizer logic:** Use a CustomPainter to render a real-time waveform. The amplitude of the wave should be driven by the `Stream<List<int>>` coming from the microphone and the model response.  
* **Components:**  
  * Reactive Oscilloscope synced to Gemini’s audio output.  
  * **Dynamic Theme System** (Eute/Saraví/Orfio) powered by **Riverpod**.  
  * "Conscious Mastery" progress visualizer.

---

## **2\. Data Structure & Schema**

To ensure consistency between the Data Agent (analysis) and the UI Agent (display), the following models are mandatory:

### **A. Core Session Metadata**

JSON  
{  
  "sessionId": "uuid\_v4",  
  "timestamp": "iso\_8601",  
  "mentorId": "eute | saravi | orfio",  
  "mode": "practice | score\_driven | jam",  
  "activeScore": "score\_id\_optional"  
}

### **B. Analysis Frame (Real-time feedback)**

JSON  
{  
  "frameId": "int",  
  "pitchHertz": "double",  
  "tempoBpm": "int",  
  "stabilityScore": "double (0.0 \- 1.0)",  
  "feedbackNote": "string\_optional"  
}

### **C. Practice Log (Persistence)**

| Field | Type | Description |
| :---- | :---- | :---- |
| id | Integer (PK) | Auto-incrementing ID for SQLite. |
| date | String | Date of session. |
| duration | Integer | Total seconds practiced. |
| mentor\_summary | Text | Final AI summary of the session performance. |

---

## **3\. Execution Roadmap (4-Day Sprint)**

| Day | Milestone | Technical Objective |
| :---- | :---- | :---- |
| **Day 1** | **Foundations & Bidi-Sync** | Establish WebSocket Handshake and basic Audio-to-Audio flow. |
| **Day 2** | **EUTE Cortex (Mode 1\)** | Implement voice commands and technical rhythmic correction. |
| **Day 3** | **ORFIO Cortex (Mode 2\)** | MusicXML parser integration and score-tracking logic. |
| **Day 4** | **SARAVÍ Cortex (Mode 3\)** | Harmonic drone generation and "Functional Elegance" polish. |

---

## **4\. Acceptance Primitives (Success Criteria)**

1. **Problem Statement:** Eliminate the "cognitive friction" of solo practice through hands-free mentorship.  
2. **Success Threshold:** System must respond in \<500ms after detecting silence or a voice interruption.  
3. **Constraint Architecture:** No REST APIs for core interaction; all data must flow through the WebSocket tunnel.  
4. **Decomposition:** Code must be modularized (Data/Domain/Presentation) following Clean Architecture.  
5. **Eval Harness:** Stress tests for latency and DSP pitch-fidelity validation.

---

## **5\. Directives for the Agents**

* **Director Agent:** Prioritize the stability of Mode 1 before escalating to Mode 3\.  
* **Data Agent:** Mandatory reference to **librosa** for initial frequency analysis.  
* **UI Agent:** Ensure Mentor transitions (Theme Switch) use a 500ms Crossfade for "Atmospheric Transformation."