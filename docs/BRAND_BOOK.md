# **BRAND BOOK: MUSAI \- THE LIVE MUSE (V1.0)**

## **1\. Brand Essence & Philosophy**

**MusAI** is not a utility; it is a **Digital Sanctuary** and a **Sovereign Creative Partner**. Rooted in the Greek *Musai*, the ecosystem eliminates "cognitive friction" for the musician by integrating fragmented tools (tuner, metronome, scores) into a fluid, **Project-Based Learning** experience.

* **Core Purpose:** Inspiration through technical mastery.  
* **Brand Voice:** Wise, technical, motivating, and surgical.  
* **Archetype:** The Muse / The Sage.

---

## **2\. Global Visual Identity**

Based on the LOGO.jpg source, the visual identity focuses on the synthesis of musical form and algorithmic structure.

* **Clearance Zone:** The logo must maintain a safety padding of **20%** of its width.  
* **Sprint Variant:** The logo may adopt the **Primary Color** of the active mentor to symbolize full system synchronization.

---

## **3\. Design System (Material Design 3\)**

We utilize the **M3 Tonal Color System** to guarantee accessibility and harmony. Each mentor represents a unique "Color Scheme" within a single Flutter architecture.

### **🔳 Modular Typography (Google Fonts)**

| M3 Level | Font Family | Weight | Usage |
| :---- | :---- | :---- | :---- |
| **Display (L/M/S)** | *Montserrat* | 700 (Bold) | Section Headers, Branding. |
| **Headline (L/M/S)** | *Montserrat* | 600 (Semi-Bold) | Mentor Names, Key Metrics. |
| **Title (L/M/S)** | *Roboto* | 500 (Medium) | Card Titles, Menu Items. |
| **Body (L/M/S)** | *Roboto* | 400 (Regular) | Instructions, AI Feedback. |
| **Label (L/M/S)** | *Roboto Mono* | 400 (Regular) | Tuner Data, BPM, Metadata. |

---

## **4\. The Triad of Mentors (Dynamic Theming)**

### **🟢 MENTOR EUTE: "Technical Purism"**

*Concept: Surgical precision, the musician’s "Terminal Mode." Inspired by Schradieck's technical rigor.*

* **Primary:** \#00FF41 (Matrix Green)  
* **OnPrimary:** \#000000  
* **Surface (Dark):** \#0A0A0A (Deep Charcoal)  
* **Secondary:** \#00F0FF (Cyan Precision)  
* **Visual Style:** Sharp edges (Radius: 8px), subtle glow effects, minimalist grids.

**UI Agent Note:** Use Card widgets with elevation 0 and defined borders.

### **🟠 MENTOR SARAVÍ: "Organic Motivation"**

*Concept: Human warmth, vocal fluidity, and the sound of wood. Inspired by lyricism and soul.*

* **Primary:** \#D87D4A (Terracotta / Violin Wood)  
* **OnPrimary:** \#FFFFFF  
* **Surface:** \#FFF8E7 (Cosmic Latte / Parchment)  
* **Secondary:** \#8B4513 (Saddle Brown)  
* **Visual Style:** High roundness (Radius: 28px), organic textures, increased kerning for airiness.

**UI Agent Note:** Implement large, soft FloatingActionButtons.

### **🔵 MENTOR ORFIO: "Professional Rigor"**

*Concept: The prestige of the stage, the conductor's baton, and high-fidelity performance.*

* **Primary:** \#D4AF37 (Metallic Gold)  
* **OnPrimary:** \#1A237E (Midnight Blue)  
* **Surface:** \#0D1117 (Deep Navy)  
* **Secondary:** \#C0C0C0 (Silver Accents)  
* **Visual Style:** Subtle gold gradients, serif typography for headlines, soft but deep shadows.

**UI Agent Note:** Use Material 3 Navigation Bar with gold active indicators.

---

## **5\. Interaction & Motion (Live Logic)**

Since this is a **Gemini Live** app, motion must reflect "Active Listening":

1. **Listening State:** A subtle sine wave in the mentor's Tertiary color.  
2. **Speaking State:** Radial pulses emanating from the Mentor's Avatar/HUD.  
3. **Transitions:** Switch mentors via a 500ms CrossFade to emphasize the transformation of the environment.

---

## **6\. Core MVP Components**

* **The Muse HUD:** A floating panel/overlay where the Mentor's persona resides.  
* **DSP Dial:** A Material 3 circular dial for the tuner with haptic feedback.  
* **The Scroll (Score View):** A high-contrast score container with a surface background tuned to the mentor’s color to reduce eye strain.