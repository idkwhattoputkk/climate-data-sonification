# WeatherScape – Data Sonification with Processing & Pure Data

> **Course:** Sistemas de Interacción – Mini Project 5  
> **Title:** Data Sonifier (Visualization + Sonification)  
> **Authors:**  
> - Student 1 – ID 8956407  

---

## 1. Project Overview

WeatherScape is a small interactive system for **data sonification** built with  
**Processing** (visualization + interaction) and **Pure Data** (sound synthesis).

The system loads a **public weather dataset** (NOAA Global Surface Summary of the Day, GSOD),  
visualizes daily values (temperature, humidity, wind speed) as a timeline, and maps these values  
to sound parameters in real time.  

As the data is read and drawn in Processing, it is also sent to Pure Data using **OSC**.  
The user can also **interact graphically** with the visualization (dragging bars and a gain  
slider), and these interactions immediately affect the sound.

This project satisfies the course requirements:

- Uses **Processing and Pure Data** together.
- Uses a **public dataset** (NOAA GSOD).
- Shows how **visual** and **sonic** representations change according to the data.
- Provides **graphical interaction** that affects both the visualization and the sound.
- Code and README are hosted on a **public GitHub repository**.

---

## 2. Dataset

- **Name:** Global Surface Summary of the Day (GSOD) – NOAA  
- **Source:** National Centers for Environmental Information (NCEI) – NOAA  
- **Format:** Daily weather observations (temperature, humidity-related variables, wind speed, etc.)  
- **License & Access:** Public dataset, accessible via NOAA and open data mirrors.

For simplicity, we export a subset for a single station / city and store it as a CSV file:

`processing/data/weather.csv`:

```text
date,temp_c,humidity,wind_speed
2025-01-01,23.4,70,3.5
2025-01-02,24.0,68,2.8
...
