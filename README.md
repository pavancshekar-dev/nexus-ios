# Nexus Chat — iOS/macOS MLX Client

Native iOS app for the QpiAI Nexus platform. Runs LLM inference **on-device** using Apple's MLX framework, or connects to a Nexus server for cloud-powered inference.

## Features

- **Dual inference mode** — Local (MLX on-device) or Server (SSE streaming)
- **4 pre-configured MLX models** — Qwen 3.5 0.8B, Qwen 3 1.7B, LFM 1.2B, Gemma 3 1B
- **Streaming token display** with auto-scroll
- **Vision support** — Attach images via PhotosPicker (Qwen 3.5 models)
- **Thinking blocks** — Expandable `<think>` reasoning display
- **Memory management** — Releases model on background, reloads on active

## Requirements

- **Xcode 16.0+**
- **iOS 18.0+** / **macOS 15.0+**
- **Swift 6.0** with strict concurrency
- **Physical Apple Silicon device** (iPhone, iPad, or Mac with M-series chip)

> MLX does not run on the iOS Simulator. You must build to a physical device.

## Build Instructions

1. **Clone this repository**
   ```bash
   git clone <repo-url>
   cd nexus-ios
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```
   Or create a new Xcode project and add this as a local Swift package.

3. **Resolve packages** — Xcode will automatically fetch `mlx-swift-lm` and its dependencies.

4. **Select your device** — Choose a physical iPhone/iPad or "My Mac" as the build target.

5. **Build and run** — Cmd+R

### Creating an Xcode Project

If you prefer a full `.xcodeproj`:

1. Open Xcode > File > New > Project > iOS App
2. Name it `NexusChat`, set deployment target to iOS 18.0
3. Add the Swift package dependency: `https://github.com/ml-explore/mlx-swift-lm` (branch: `main`)
4. Copy all files from `NexusChat/` into the project
5. Add `NexusChat.entitlements` to the target's Signing & Capabilities
6. Enable "Increased Memory Limit" capability

## Architecture

```
NexusChat/
├── Models/
│   ├── ChatMessage.swift          — Message model + <think> parsing
│   └── ModelConfiguration.swift   — MLX model enum + HuggingFace IDs
├── Services/
│   ├── MLXInferenceService.swift  — Local MLX load/generate
│   └── NexusAPIService.swift      — Server auth + SSE streaming
├── ViewModels/
│   ├── ChatViewModel.swift        — Dual-mode chat logic
│   └── ConnectionViewModel.swift  — Server connection management
└── Views/
    ├── ContentView.swift          — TabView root
    ├── ChatView.swift             — Chat UI
    ├── ChatBubbleView.swift       — Message bubbles
    ├── MessageInputView.swift     — Text + photo input
    ├── ConnectView.swift          — Server connection form
    └── ModelsView.swift           — Model browser + mode picker
```

## Default Models

| Model | HuggingFace ID | Size | Vision |
|-------|---------------|------|--------|
| Qwen 3.5 0.8B (default) | mlx-community/Qwen3.5-0.8B-4bit | ~0.5 GB | Yes |
| Qwen 3 1.7B | mlx-community/Qwen3-1.7B-4bit | ~1.0 GB | No |
| LFM 1.2B Thinking | LiquidAI/LFM2.5-1.2B-Thinking-MLX-4bit | ~0.7 GB | No |
| Gemma 3 1B | mlx-community/gemma-3-1b-it-4bit | ~0.6 GB | No |

Models are downloaded from HuggingFace Hub on first launch and cached locally.

## Server Mode

To use server inference, go to the **Connect** tab and enter:
- Your Nexus server URL (e.g., https://nexus.example.com)
- Login credentials

The app will authenticate via `POST /api/auth/login`, register the device via `POST /api/mobile/register`, and stream chat responses via SSE from `POST /api/chat`.

## License

Part of the QpiAI Nexus platform.
