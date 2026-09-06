# Circle to Search & Google Lens for Nilastia

Experience Android's iconic **Circle to Search** and **Google Lens** directly on the Linux desktop, engineered seamlessly for the Nilastia desktop shell.

---

# Circle to Search & Google Lens for Nilastia

Experience Android's iconic **Circle to Search** and **Google Lens** directly on the Linux desktop, engineered seamlessly for the Nilastia desktop shell.

---

## Features

- **Google Lens Quad-Palette Shimmer:** Real-time hardware-accelerated Vulkan/GLSL shader interpolating the iconic 4-color palette (Blue, Red, Yellow, Green) around display edges.
- **Smart Gesture Recognition:**
  - **Circle / Loop:** Drawing a closed loop around any visual element instantly triggers Google Lens visual search.
  - **Line Swipe / Tap:** Drawing a stroke across words or single-tapping selects text and presents Android-style teardrop draggable handles to fine-tune the selection range.
- **Integrated Google Lens:** Visual search powered by Chrome's native context-menu endpoint (`source=lns.web.ccm`), opening active searches without session expiration bugs.
- **Live In-Place Translation:** Automatically translates screen text into floating frosted-glass cards directly overlaid on the original words.
- **Dynamic Language Selector:** Auto-detect source language with quick-switch dropdown menu for target languages.
- **Material 3 Floating Actions:** Quick actions for `Copy`, `Web Search`, `Translate`, and `Google Lens`.

---

## Usage

Press **`Super+S`** (or run `quickshell -c niri-nilastia-shell ipc call circletosearch open`):

1. **Draw a Circle:** Draw around any object, image, or area to immediately launch Google Lens.
2. **Draw a Line or Tap Text:** Swipe across words or tap any word to highlight text and reveal Android drag handles.
3. **Adjust Range:** Drag the teardrop handles at the start or end of the text selection.
4. **Live Translate:** Switch to *Live Translate* at the bottom and pick your target language from the dropdown.
5. **Escape:** Instantly closes the overlay.
