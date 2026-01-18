---
name: Unified Notification Control Refactoring
overview: Implement unified notification bar control for both local and remote playback by refactoring AudioHandler to support a "Hosted Mode" and integrating it with RemotePlayerController.
todos:
  - id: refactor-audio-handler
    content: Refactor MyAudioHandler to add remote mode and external state support
    status: completed
  - id: update-unified-controller
    content: Update UnifiedPlayerController to pass AudioHandler to RemoteController
    status: completed
  - id: impl-remote-controller
    content: Implement RemotePlayerController integration with AudioHandler
    status: completed
  - id: update-local-controller
    content: Update LocalPlayerController to enforce local mode
    status: completed
---

# Unified Notification Control Refactoring Plan

This plan implements the "AudioHandler Hosted Mode" to allow the system notification bar to control both local and remote devices seamlessly.

## Core Architecture

1.  **Dual-Mode AudioHandler**: `MyAudioHandler` will have two modes:

    -   **Local Mode** (Default): Drives `just_audio` player directly (current behavior).
    -   **Remote/Hosted Mode**: Disconnects from local player logic. Accepts state updates from `RemotePlayerController` and forwards UI clicks (Play/Pause/Next) to `RemotePlayerController` callbacks.

2.  **Controller Integration**:

    -   `RemotePlayerController`: Injects `AudioHandler`, enables "Hosted Mode", and bridges the API polling loop to the notification state.
    -   `LocalPlayerController`: Ensures `AudioHandler` is in "Local Mode".
    -   `UnifiedPlayerController`: Manages the lifecycle, ensuring `AudioHandler` persists across device switches.

## Implementation Steps

### 1. Refactor `MyAudioHandler`

file: `lib/data/services/audio_handler.dart`

- Add `_isRemoteMode` flag.
- Add `setRemoteMode(bool)` to toggle modes.
- Add `setRemoteCallbacks(...)` for Play, Pause, Next, Previous.
- Add `updateStateFromExternal(PlayerState)` to update notification UI manually.
- Update `_broadcastState` and `play/pause/etc` methods to respect `_isRemoteMode`.

### 2. Update `RemotePlayerControllerImpl`

file: `lib/data/providers/player/remote_player_controller.dart`

- Update constructor to accept `MyAudioHandler`.
- In constructor: Call `handler.setRemoteMode(true)` and register callbacks (e.g., calling `this.playPause()`).
- In `_updateState`: Call `handler.updateStateFromExternal(newState)` to sync UI.
- In `dispose`: Clear callbacks but **do not** stop the handler (to keep notification alive).

### 3. Update `LocalPlayerControllerImpl`

file: `lib/data/providers/player/local_player_controller.dart`

- In `_initializeHandler`: Call `handler.setRemoteMode(false)`.
- Ensure `dispose` behavior is consistent (stops local player, but `UnifiedPlayerController` should manage Service lifecycle if needed).

### 4. Update `UnifiedPlayerController`

file: `lib/data/providers/player/player_provider.dart`

- Update `_initializePlayerController` to pass `handler` to `RemotePlayerControllerImpl`.
- Ensure `AudioHandler` singleton is correctly retrieved and shared.
- Adjust `dispose` logic to prevent accidental service destruction during device switching.

## Verification

- **Local Playback**: Should work as before (notification syncs with local audio).
- **Remote Playback**: Notification should show remote song title/state and buttons should control remote device.
- **Switching**: Switching devices should update notification without disappearing.