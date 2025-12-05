# 📡 D A T A  C O L L E C T O R

### The Senses of Canvas.

![Platform](https://img.shields.io/badge/Platform-iOS_18-black)
![Fusion](https://img.shields.io/badge/Sensor-Fusion-blue)
![Concurrency](https://img.shields.io/badge/Stream-AsyncSequence-orange)
![Logic](https://img.shields.io/badge/Engine-Deterministic-green)

---

## 📚 Contents
- [Overview](#-overview)
- [The Stack](#️-the-stack)
- [The Vibe Engine](#-the-vibe-engine)
- [Usage](#-usage)
- [Navigation](#-navigation)

---

## 📖 Overview
**DataCollector** is the sensory nervous system. It interfaces with hardware sensors (`CoreMotion`, `CoreLocation`) to build a real-time picture of the user's context. It handles the "Dirty Work" of sensor fusion, smoothing, and normalization.

---

## ⚡️ The Stack

| Sensor | Framework | Insight |
| :--- | :--- | :--- |
| **Motion** | `CMMotionActivity` | Walking, Running, Automotive, Stationary. |
| **Location** | `CLLocation` | Semantic context (Home, Work, Gym). |
| **Context** | `Pedometer` | Step cadence and pace. |

---

## 🧠 The Vibe Engine
Raw data is noise. The **Vibe Engine** is the deterministic logic layer that converts noise into signal.

**The State Machine**:
-   *Input*: `Stationary` + `03:00 AM` + `Home`
-   *Output*: **Sleep State**
-   *Input*: `Walking` + `08:00 AM` + `Transit`
-   *Output*: **Commute State**

This logic is rigorously verified by `VibeEngineTests` to ensure 100% deterministic behavior across all timezones.

---

## 🚀 Usage

```swift
let collector = SensorDataCollector()

// Swift Concurrency Stream
for await snapshot in collector.stream {
    print("User is \(snapshot.activityType) at \(snapshot.location)")
}
```

---

## 🧭 Navigation

| Package | Role |
| :--- | :--- |
| [**Canvas**](https://github.com/InfiniteEvolution/Canvas) | The App |
| **DataCollector** *(You Are Here)* | The Senses |
| [**Trainer**](https://github.com/InfiniteEvolution/Trainer) | The Brain |
| [**Store**](https://github.com/InfiniteEvolution/Store) | The Memory |
| [**Logger**](https://github.com/InfiniteEvolution/Logger) | The Console |

---
*Sensing with Sensitivity.*
