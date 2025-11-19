# WeatherScape – Data Sonification of Daily Weather

> **Course:** Interaction Systems  
> **Project:** Visualisation & Sonification of Open Data using Processing + Pure Data  
> **Student:** Emmanuel Umaña (ID: 8956407)  
> **Semester:** 2025-2

---

## 1. Concept

**WeatherScape** is an interactive system that turns daily weather data into both **visual** and **auditory** information.

The project explores how people can *hear* patterns in a time series dataset (temperature, humidity, wind) while also *seeing* the same information in a clear visualisation. The user can manipulate the data directly on screen and immediately perceive the effect in the sound.

---

## 2. Dataset

- **Source:** NOAA – Global Surface Summary of the Day (GSOD)  
- **Station used:** `010010-99999`  
- **Year used:** 2019 (first 106 days)  
- **Format:** daily observations

From the original `.op` file we extracted:

- **Date** (`YEARMODA`) → converted to `YYYY-MM-DD`
- **Average temperature** (`TEMP`, in °C)
- **Dew point** (`DEWP`)
- **Mean wind speed** (`WDSP`)

We created a simplified CSV:

processing/WeatherScape/data/weather.csv
----------------------------------------
date,temp_c,humidity,wind_speed
2019-01-01,24.0,62,8.9
...

Where:

- `humidity` is a **normalized mapping of dew point** scaled to 0–100 for interaction and sonification.

The goal of the preprocessing is not to be meteorologically perfect, but to obtain a clean, consistent dataset that is easy to explore visually and sonically.

---

## 3. System Architecture

The system is split into two main components:

### 3.1 Processing (visualisation + interaction, OSC sender)

- Loads `data/weather.csv`.
- Normalizes values to `[0, 1]`.
- Draws:
  - A line plot for temperature over time.
  - A bar chart for humidity.
  - A moving cursor that scans the time axis.
- Sends each frame as an OSC message:
  - Address: `/weather`
  - Payload: `tempNorm, humNorm, windNorm, masterGain`.

### 3.2 Pure Data (audio synthesis, OSC receiver)

- Receives `/weather` via `netreceive -u -b 8000`.
- Decodes the OSC packet with `oscparse` and `route weather`.
- Maps each float to synthesis parameters:
  - `tempNorm` → oscillator frequencies (two oscillators).
  - `humNorm` → amplitude envelope.
  - `windNorm` → low-pass filter cutoff and noise amount.
  - `masterGain` → final output gain.
- Adds a short delay to give a small sense of space.

Communication uses **OSC over UDP** on `127.0.0.1`:

- Processing → `localhost:8000` (Pure Data)
- Implemented with the **oscP5** library in Processing and `netreceive` in Pure Data.

---

## 4. Interaction Design

User interactions in the Processing interface:

- **Space bar**: start / pause the scan over the time series.
- **Vertical bars (humidity)**:
  - The user can **drag bars up or down** with the mouse.
  - This directly edits the humidity value on that day.
  - The new value is sent immediately to Pure Data, so the sound changes in real time.
- **Master gain slider**:
  - Horizontal slider at the bottom of the screen.
  - Controls the global volume in Pure Data and prevents clipping.
- A text HUD shows the current date, temperature, humidity and wind speed.

The interface is intentionally simple and high-contrast, focusing on the relationship between data and sound instead of graphical decoration.

---

## 5. Sound Mapping Strategy

The sonification uses a **direct, monotonic mapping** between data dimensions and sound parameters.

### 5.1 Temperature (°C) → Pitch

- `tempNorm ∈ [0,1]` is mapped to frequency ranges:
  - Main oscillator: `freq₁ = 200 + tempNorm * 800` Hz (≈200–1000 Hz)
  - Low oscillator: `freq₂ = 100 + tempNorm * 400` Hz (≈100–500 Hz)
- Both oscillators are added together to create a richer harmonic sound.
- Perception: **hotter days ⇒ higher pitch**.

### 5.2 Humidity (%) → Loudness

- `humNorm ∈ [0,1]` controls an envelope using `line~`:
  - `amp = humNorm * 0.8`
- `line~` smooths changes to avoid clicks when the user drags the bars.
- Perception: **more humid days ⇒ louder sound**.
- When the user edits a bar, the loudness for that day changes immediately.

### 5.3 Wind speed → Brightness & Noise

- `windNorm ∈ [0,1]` controls:
  - Low-pass filter cutoff:
    - `cutoff = 500 + windNorm * 4000` Hz  
    - Implemented with `lop~`, giving brighter timbre on windy days.
  - Noise level:
    - A `noise~` source is scaled by `windNorm * 0.5` and mixed with the tonal signal.
    - This creates a subtle “windy” texture when wind speed is high.

### 5.4 Master gain → Final volume

- `masterGain ∈ [0,1]` comes from the Processing slider.
- In Pure Data it is clipped to `[0,1]` and converted with `sig~`.
- It multiplies the final combined signal before the echo and `dac~`.

### 5.5 Short delay

- A short delay (≈250 ms) is added using `delwrite~` / `delread~`.
- The delayed signal is mixed back at a lower level to give a mild echo.
- This makes the sonification feel more spacious while keeping the data mapping clear.

Overall, the mapping is:

- **Consistent** – same data values always produce the same sound.
- **Intuitive** – heat ↔ pitch, humidity ↔ loudness, wind ↔ brightness/noise.
- **Continuous** – small changes in the data generate smooth changes in sound.

---

## 6. Files Overview

```text
processing/
└── WeatherScape/
    ├── WeatherScape.pde      # Main Processing sketch (visual + OSC)
    └── data/
        └── weather.csv       # Simplified weather dataset

puredata/
└── weatherscape.pd           # Pure Data patch (OSC + synthesis)

README.md                     # Project documentation
```

---

## 7. How to Run

### 7.1 Requirements

- **Processing 4.x**
- **oscP5** library for Processing
- **Pure Data (Pd Vanilla)** 0.56 or newer
- macOS / Windows / Linux with audio output

### 7.2 Install oscP5 in Processing

1. Open Processing.
2. `Sketch → Import Library… → Add Library…`
3. Search for **“oscP5”**.
4. Click **Install**.

### 7.3 Running the system

1. **Start Pure Data**
   - `File → Open… → puredata/weatherscape.pd`
   - `Media → Audio ON` (enable DSP).

2. **Start Processing**
   - `File → Open… → processing/WeatherScape/WeatherScape.pde`
   - Press **Run** (`▶`).

3. **Interact**
   - Press **SPACE** to play/pause the temporal scan.
   - Move the mouse over the humidity bars and drag them vertically to edit values.
   - Adjust the bottom slider to change the global volume.
   - Watch the current date and numeric values in the HUD while listening to the sound.

If everything is configured correctly, you will see the moving cursor in Processing and hear a continuous sound that evolves according to the weather data and your interactions.

### 7.4 Demo video

- **Demo video:** [Watch demo (YouTube)](https://youtu.be/i1GqkIZ5Tnw)

Watch the video to see the system in action and to confirm the visual-sonic mapping described above.

---

## 8. Design Decisions & Limitations

- The mapping focuses on **three main variables** (temperature, humidity, wind) to keep the sound scene understandable.
- Humidity is derived from dew point and scaled to 0–100; this is sufficient for interaction and for hearing relative changes, even if it is not a physically exact humidity measure.
- The synthesis uses simple building blocks (sine oscillators, noise, low-pass filter, delay) to keep the Pure Data patch readable for teaching purposes.
- The system assumes the dataset fits in memory (106 days). For larger datasets, subsampling or windowing could be used.

---

## 9. Possible Extensions

- Support multiple weather stations or years and switch between them from the interface.
- Add alternative synthesis modes (FM, granular, different tunings).
- Allow exporting the sonification as audio files.
- Let the user draw synthetic weather patterns and compare their sound to real data.

---

## 10. License

This project is for educational purposes only.  
Dataset © NOAA / NCEI – Global Surface Summary of the Day (GSOD).
