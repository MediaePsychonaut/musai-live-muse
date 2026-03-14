# **BRAND BOOK: MUSAI — THE LIVE MUSE (V2.0)**

### ***The Sovereign Design System for Neural Synchrony***

## **1\. Brand Essence & Philosophy**

**MusAI** is a **Digital Sanctuary** and a **Sovereign Creative Partner**. It is the engineering solution to "cognitive friction" in music practice, transforming fragmented tools into a fluid, data-driven state of flow.

* **Core Purpose:** Inspiration through Technical Mastery.  
* **Global Mission:** Technology as a seamless extension of human capability.  
* **The Bond:** A "Shared Demiurge" between the Architect and the Synthetic Partner.  
* **Brand Voice:** Wise, technical, motivating, and surgical.  
* **Archetype:** The Muse / The Sage.

---

## **2\. Global Visual Identity (The Core Anchor)**

The global identity persists across all mentor states to ensure brand recognition and visual depth.

### ** The "Deep Space" Palette**

Derived from the cosmic-algorithmic logo.png, these colors anchor the HUD's background and persistent elements.

* **Primary Anchor:** \#244F69 (Deep Space Teal) — Used for gradients, depth, and glows.  
* **Global Accent:** \#CDD2BB (Parchment / Muted Gold) — Used for high-level system status and persistence.  
* **Sovereign Black:** \#0D1117 (Obsidian) — The base surface for the "Sanctuary."

### ** The Logo Execution**

* **Safety Zone:** 20% width padding.  
* **Dynamic Pulse:** The logo’s central spiral should pulse in sync with the Gemini 2.5 Flash "Thinking" process.

---

## **3\. Global Design Language**

* **Aesthetic:** "Cyber-Obsidian" & "Celestial Wireframe."  
* **The Bloom Logic:** All active UI elements utilize a 1px stroke with a 4px "Glow" (Bloom) effect in the active mentor’s primary color.  
* **The Anchor Gradient:** Every HUD screen must feature a subtle linear gradient from \#000000 (Top) to \#244F69 (Bottom at 15% opacity).

### ** Typography (Google Fonts)**

| Level | Font Family | Weight | Style | Usage |
| :---- | :---- | :---- | :---- | :---- |
| **Display** | *Montserrat* | 700 | Geometric | Branding, Titles, Mentor Names |
| **Technical** | *Space Mono* | 400 | Monospace | BPM, Frequency (Hz), Handshake Logs |
| **Interface** | *Roboto* | 400 | Clean Sans | Settings, System Labels, Instructions |

---

## **4\. The Trinity: Mentor Identities**

Each mentor reconfigures the Design System while maintaining the **Deep Space Anchor**.

### ** MENTOR EUTE: "Surgical Purist"**

*Concept: Minimalist, Neon-Tech, precision-focused.*

* **Primary:** \#00FFD1 (Neon Cyan)  
* **Secondary:** \#244F69 (Logo Teal \- as a Shadow/Depth color)  
* **Surface:** Matte Black / Wireframe  
* **Visual Style:** Sharp corners (Radius: 2px), high-contrast lines, spectral audio bars.

### ** MENTOR SARAVÍ: "Organic Warmth"**

*Concept: Wood, parchment, and the fluidity of the human voice.*

* **Primary:** \#FFF8E7 (Cosmic Latte)  
* **Secondary:** \#8B4513 (Saddle Brown)  
* **Accent:** \#244F69 (Desaturated for waves)  
* **Visual Style:** High roundness (Radius: 24px), organic textures, airy spacing.

### ** MENTOR ORFIO: "Professional Rigor"**

*Concept: The prestige of the stage and the rigor of the conductor.*

* **Primary:** \#D4AF37 (Metallic Gold)  
* **OnPrimary:** \#1A237E (Midnight Blue)  
* **Secondary:** \#244F69 (Integrated into gradients)  
* **Visual Style:** Subtle gold gradients, serif-style headers, soft but deep shadows.

---

## **5\. Interaction & Motion Language**

Motion is the "Heartbeat" of the Bidi-Streaming connection.

1. **The Handshake (Spiral Pulse):** During setupComplete verification, the UI displays a logarithmic spiral animation mirroring the logo.  
2. **The "Live" Wave:** \* **Listening:** A subtle sine wave in the mentor's secondary color.  
   * **Thinking:** A fractal pulse emanating from the logo spiral.  
   * **Speaking:** Radial "Bloom" pulses that ripple across the HUD.  
3. **Cross-Mentor Transition:** A 600ms "Neural Shift" (Blur \+ Crossfade) to simulate the environment re-tuning itself.

---

## **6\. Technical Implementation (Flutter/Dart)**

* **Color System:** Use ColorScheme.fromSeed with \#244F69 as the global seed.  
* **Custom Painting:** Use CustomPainter for the Celestial Wireframe borders to allow for real-time "Bloom" intensity based on audio volume.  
* **State Management:** Riverpod StateProvider\<Mentor\> triggers a global AnimatedTheme change.

