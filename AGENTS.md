# AGENTS.md — ReadZen Mobile App Engineering Guidelines

This file defines the mandatory architecture, coding standards, product constraints, and verification rules for AI agents and developers working on the **ReadZen** repository.

---

## 1. Source of Truth & Governance
* **Primary Specification:** [assignment_01_spec.md](assignment_01_spec.md)
* **Grading & Acceptance Rubric:** [evaluation_criteria.md](evaluation_criteria.md)
* **Change Log Rule (Mandatory):** Assignment 02 is graded strictly against Assignment 01. Any deviation from `assignment_01_spec.md` (features, architecture, DB schema, or UI flows) **MUST** be documented in Section 7.2 (Change Log) of `assignment_01_spec.md` with clear rationale before or alongside the code change.

---

## 2. Product Scope & Non-Negotiable Constraints
* **App Identity:** ReadZen — 100% Free, Offline-First, English-only Ebook Reader, AI Audiobook (TTS), Lofi Sanctuary & Xiangqi app.
* **No Authentication:** Do **NOT** implement login, sign-up, or user account flows. All user data lives locally on the device.
* **Exact 4-Tab Navigation (`StatefulShellRoute`):**
  1. **Tab 1 — Discover:** English catalog (Standard Ebooks CDN), Search, Continue Reading card, Favorite button (`❤️`) on books, and a **top-right circular button** that opens the Lofi Music Bottom Sheet.
  2. **Tab 2 — Library:** Three sub-sections: `Downloaded` | `Favorites` | `My Uploads` (local import for `.epub`, `.pdf`, `.txt`).
  3. **Tab 3 — Game:** **Xiangqi (Cờ Tướng) only** vs AI with **3 difficulty levels**: `Easy`, `Medium`, `Hard` (plus `Undo`, `Hint`, `New Game`, side selection).
  4. **Tab 4 — Setting:** Theme switcher (`Paper Light`, `Warm Sepia`, `Midnight Dark`), AI Voice Pack manager, Storage & Cache cleaner, App info.
* **Reader Screen & Audio Mutual Exclusion:**
  * AI TTS controls live **inside the Reader Screen**.
  * **Mutual Exclusion Rule:** Starting TTS playback **MUST automatically pause/stop** Lofi background music (`AudioCoordinator`). TTS and Lofi must never play simultaneously.

---

## 3. Tech Stack & Architecture Rules

### Approved Stack
* **Framework:** Flutter (Latest Stable, Dart null-safe)
* **State Management:** Riverpod (`flutter_riverpod` / `riverpod_annotation`)
* **Routing:** `go_router`
* **Local Persistence:** `drift` (SQLite) + `shared_preferences`
* **Networking & Downloads:** `dio`
* **AI TTS Engine:** `sherpa_onnx` (Dart FFI) running **Kokoro-82M** (default) and **Piper** (lightweight fallback)
* **Lofi Audio:** `just_audio` + `audio_service`
* **Xiangqi AI Engine:** **Fairy-Stockfish** (C++ via `dart:ffi`, UCI protocol)

### Feature-First Clean Architecture
Strictly maintain the following folder structure under `lib/`:
```text
lib/
├── core/
│   ├── audio/             # Global AudioCoordinator (TTS + Lofi mutual exclusion)
│   ├── database/          # Drift tables, DAOs, migrations
│   ├── network/           # Dio client, DownloadManager
│   ├── router/            # GoRouter configuration
│   └── theme/             # Paper Light, Warm Sepia, Midnight Dark themes
└── features/
    ├── discover/          # data/, domain/, presentation/
    ├── library/           # data/, domain/, presentation/
    ├── reader/            # data/, domain/, presentation/
    ├── game/              # data/, domain/, presentation/
    └── settings/          # data/, domain/, presentation/
```

### Layering & Concurrency Rules
1. **Strict Separation:** `presentation/` widgets must only interact with Riverpod controllers/providers. Never call Drift DAOs, Dio, or FFI directly from UI widgets.
2. **Zero Main-Thread Blocking:**
   * All `sherpa_onnx` TTS synthesis MUST run in a dedicated background **Dart Isolate**.
   * All `Fairy-Stockfish` move calculations MUST run in a dedicated background **Dart Isolate**.
   * Large `.epub`/`.pdf` parsing during import or opening MUST run in a background Isolate (`compute` / `Isolate.run`).
3. **Global Audio Ownership:** All audio state transitions must pass through `AudioCoordinator` in `lib/core/audio/`.

---

## 4. UI/UX & Reliability Standards
* **4 Required States:** Every asynchronous screen or list (Discover, Library, Book Detail, Voice Packs) must gracefully handle:
  1. `Normal` (data displayed)
  2. `Loading` (shimmer/skeleton or progress indicator)
  3. `Empty` (helpful message + clear CTA)
  4. `Error` (user-friendly message + `Retry` button; offline fallback when cached data exists)
* **Accessibility:** Minimum tap target `48x48 dp`, semantic labels on icon-only buttons, WCAG AA contrast across all 3 themes.
* **Permissions:** Request permissions **Just-in-Time** (File Picker only on Import; Notification permission only when starting background audio on Android 13+). Never request unused permissions (Location, Camera, Contacts).

---

## 5. Security, Testing & Git Workflow
* **Secrets:** Never hardcode API keys, tokens, or credentials. Do not collect PII. All CDN downloads must use HTTPS.
* **Testing Mapped to Spec:**
  * Write unit tests for core business logic (`AudioCoordinator` mutual exclusion, Xiangqi move validation/FEN, EPUB text normalization/chunking, Drift DAOs) and reference the corresponding `AC-*` IDs from `assignment_01_spec.md`.
  * Maintain a manual test checklist/report mapped to all Must-have Acceptance Criteria.
* **Verification Commands (Run before committing):**
  ```bash
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  flutter analyze
  flutter test
  ```
* **Git Hygiene:** Use small, focused feature branches (`feat/discover-catalog`, `feat/reader-tts`, `feat/xiangqi-ai`, etc.) with clear commit messages. Never dump all changes into a single commit at the end.
