/* 
 * WeatherScape: Data Sonification with Processing + Pure Data
 *
 * - Loads a public weather dataset (NOAA GSOD simplified CSV)
 * - Visualizes daily temperature, humidity and wind speed
 * - Sends normalized values to Pure Data via OSC
 * - Allows interactive editing of data points (drag bars) which changes the sound
 *
 * Requirements:
 * - Processing 4.x (Java mode)
 * - oscP5 library (Sketch > Import Library > Add Library... > search "oscP5")
 * - Pure Data patch listening on UDP port 8000
 */

import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress pdAddress;

Table weatherTable;

// Data structure for one row (one day)
class WeatherPoint {
  String date;
  float tempC;
  float humidity;
  float windSpeed;
  
  // normalized [0,1] for sound and visualization
  float tempNorm;
  float humNorm;
  float windNorm;
}

WeatherPoint[] points;

int numPoints = 0;

// Visualization parameters
int marginLeft = 80;
int marginRight = 40;
int marginTop = 80;
int marginBottom = 120;

int graphWidth, graphHeight;

// Playback and interaction
int currentIndex = 0;
boolean isPlaying = true;
int framesPerStep = 12;   // how many frames per data step
int frameCounter = 0;

int selectedIndex = -1;   // index of point being dragged
boolean isDragging = false;

// Global user gain (0..1) controlled by mouseX in a horizontal slider
float userGain = 0.7;

// Data ranges for normalization
float minTemp, maxTemp;
float minHum, maxHum;
float minWind, maxWind;

void setup() {
  size(1000, 600);
  surface.setTitle("WeatherScape - Data Sonification");
  smooth(4);
  
  graphWidth = width - marginLeft - marginRight;
  graphHeight = height - marginTop - marginBottom;
  
  // Init OSC
  oscP5 = new OscP5(this, 12000); // optional local port (not strictly needed)
  pdAddress = new NetAddress("127.0.0.1", 8000); // PD listening UDP port
  
  loadWeatherData();
  computeNormalization();
  
  // Send initial point
  if (numPoints > 0) {
    sendToPD(points[currentIndex]);
  }
}

void draw() {
  background(15);
  drawTitle();
  drawAxes();
  drawSeries();
  drawCurrentIndicator();
  drawTimeline();
  drawControls();
  
  updatePlayback();
}

/* ---------- DATA LOADING & NORMALIZATION ---------- */

void loadWeatherData() {
  weatherTable = loadTable("weather.csv", "header");
  if (weatherTable == null) {
    println("ERROR: weather.csv not found in data/ folder");
    exit();
  }
  
  numPoints = weatherTable.getRowCount();
  points = new WeatherPoint[numPoints];
  
  int i = 0;
  for (TableRow row : weatherTable.rows()) {
    WeatherPoint wp = new WeatherPoint();
    wp.date = row.getString("date");
    wp.tempC = row.getFloat("temp_c");
    wp.humidity = row.getFloat("humidity");
    wp.windSpeed = row.getFloat("wind_speed");
    points[i++] = wp;
  }
}

void computeNormalization() {
  // Initialize ranges
  if (numPoints == 0) return;
  
  minTemp = maxTemp = points[0].tempC;
  minHum = maxHum = points[0].humidity;
  minWind = maxWind = points[0].windSpeed;
  
  for (int i = 1; i < numPoints; i++) {
    WeatherPoint wp = points[i];
    minTemp = min(minTemp, wp.tempC);
    maxTemp = max(maxTemp, wp.tempC);
    
    minHum = min(minHum, wp.humidity);
    maxHum = max(maxHum, wp.humidity);
    
    minWind = min(minWind, wp.windSpeed);
    maxWind = max(maxWind, wp.windSpeed);
  }
  
  // Avoid degenerate ranges
  if (maxTemp == minTemp) maxTemp = minTemp + 1;
  if (maxHum == minHum) maxHum = minHum + 1;
  if (maxWind == minWind) maxWind = minWind + 1;
  
  // Compute normalized values
  for (int i = 0; i < numPoints; i++) {
    WeatherPoint wp = points[i];
    wp.tempNorm = norm(wp.tempC, minTemp, maxTemp);
    wp.humNorm = norm(wp.humidity, minHum, maxHum);
    wp.windNorm = norm(wp.windSpeed, minWind, maxWind);
  }
}

/* ---------- VISUALIZATION ---------- */

void drawTitle() {
  fill(240);
  textAlign(LEFT, TOP);
  textSize(18);
  text("WeatherScape - Daily Weather Sonification", marginLeft, 20);
  
  textSize(12);
  String info = "Dataset: NOAA GSOD (simplified) | Keys: Temp (°C), Humidity (%), Wind (m/s)";
  fill(180);
  text(info, marginLeft, 42);
}

void drawAxes() {
  stroke(120);
  strokeWeight(1);
  
  // X axis
  line(marginLeft, marginTop + graphHeight, marginLeft + graphWidth, marginTop + graphHeight);
  // Y axis (temperature)
  line(marginLeft, marginTop, marginLeft, marginTop + graphHeight);
  
  fill(180);
  textAlign(LEFT, CENTER);
  text("Date →", marginLeft + graphWidth - 60, marginTop + graphHeight + 24);
  pushMatrix();
  translate(marginLeft - 50, marginTop + graphHeight / 2);
  rotate(-HALF_PI);
  text("Temperature (normalized)", 0, 0);
  popMatrix();
}

void drawSeries() {
  if (numPoints == 0) return;
  
  // Draw temperature as line + points
  noFill();
  stroke(80, 180, 255);
  strokeWeight(2);
  
  beginShape();
  for (int i = 0; i < numPoints; i++) {
    float x = indexToX(i);
    float y = tempToY(points[i].tempNorm);
    vertex(x, y);
  }
  endShape();
  
  // Draw humidity as bar height (background bars)
  noStroke();
  for (int i = 0; i < numPoints; i++) {
    float x = indexToX(i);
    float barWidth = max(2, graphWidth / max(40, numPoints)); // thin bars
    float humHeight = map(points[i].humNorm, 0, 1, 0, graphHeight * 0.6);
    
    float baseY = marginTop + graphHeight;
    float topY = baseY - humHeight;
    
    // Light blue bars for humidity
    fill(40, 80, 180, 120);
    rectMode(CORNERS);
    rect(x - barWidth/2, baseY, x + barWidth/2, topY);
  }
}

void drawCurrentIndicator() {
  if (numPoints == 0) return;
  
  WeatherPoint wp = points[currentIndex];
  float x = indexToX(currentIndex);
  float yTemp = tempToY(wp.tempNorm);
  
  // Vertical line
  stroke(255, 200, 0, 200);
  strokeWeight(1);
  line(x, marginTop, x, marginTop + graphHeight);
  
  // Highlight point
  noStroke();
  fill(255, 220, 0);
  ellipse(x, yTemp, 14, 14);
  
  // Display current values
  fill(230);
  textAlign(LEFT, TOP);
  textSize(13);
  
  String label = "Current: " + wp.date +
                 " | Temp: " + nf(wp.tempC, 0, 1) +
                 " °C | Hum: " + nf(wp.humidity, 0, 1) +
                 " % | Wind: " + nf(wp.windSpeed, 0, 1) + " m/s";
  text(label, marginLeft, marginTop + graphHeight + 30);
}

void drawTimeline() {
  // Simple tick marks on X axis for first, middle, last
  if (numPoints < 2) return;
  
  int[] indices = {0, numPoints/2, numPoints-1};
  
  fill(180);
  textAlign(CENTER, TOP);
  textSize(10);
  
  for (int idx : indices) {
    float x = indexToX(idx);
    float y = marginTop + graphHeight;
    stroke(100);
    line(x, y, x, y + 5);
    
    noStroke();
    String d = points[idx].date;
    text(d, x, y + 8);
  }
}

void drawControls() {
  // Play/Pause instruction
  fill(200);
  textAlign(LEFT, TOP);
  textSize(12);
  text("Controls: [SPACE] Play/Pause | Drag bars vertically to edit humidity | Drag gain slider", 
       marginLeft, height - 60);
  
  // Gain slider
  int sliderX = marginLeft;
  int sliderY = height - 30;
  int sliderW = 260;
  int sliderH = 10;
  
  // Background
  noStroke();
  fill(60);
  rect(sliderX, sliderY, sliderX + sliderW, sliderY + sliderH);
  
  // Filled part
  float knobX = sliderX + userGain * sliderW;
  fill(0, 200, 150);
  rect(sliderX, sliderY, knobX, sliderY + sliderH);
  
  // Knob
  fill(230);
  ellipse(knobX, sliderY + sliderH/2, 12, 12);
  
  fill(200);
  textAlign(LEFT, BOTTOM);
  text("Master Gain: " + nf(userGain, 0, 2), sliderX + sliderW + 10, sliderY + sliderH);
}

/* ---------- PLAYBACK & INTERACTION ---------- */

void updatePlayback() {
  if (!isPlaying || numPoints == 0) return;
  
  frameCounter++;
  if (frameCounter >= framesPerStep) {
    frameCounter = 0;
    currentIndex = (currentIndex + 1) % numPoints;
    sendToPD(points[currentIndex]);
  }
}

float indexToX(int idx) {
  if (numPoints <= 1) return marginLeft;
  float t = idx / (float)(numPoints - 1);
  return marginLeft + t * graphWidth;
}

float tempToY(float tempNorm) {
  // tempNorm in [0,1], 0 bottom, 1 top
  return map(tempNorm, 0, 1, marginTop + graphHeight, marginTop);
}

/* ---------- MOUSE & KEYBOARD ---------- */

void keyPressed() {
  if (key == ' ' ) {
    isPlaying = !isPlaying;
  }
}

void mousePressed() {
  // Check if on gain slider
  int sliderX = marginLeft;
  int sliderY = height - 30;
  int sliderW = 260;
  int sliderH = 10;
  
  if (mouseY >= sliderY - 8 && mouseY <= sliderY + sliderH + 8 &&
      mouseX >= sliderX && mouseX <= sliderX + sliderW) {
    userGain = constrain((mouseX - sliderX) / float(sliderW), 0, 1);
    // Send immediate update for current point
    if (numPoints > 0) sendToPD(points[currentIndex]);
    return;
  }
  
  // Otherwise, check nearest bar for humidity editing
  if (mouseX >= marginLeft && mouseX <= marginLeft + graphWidth &&
      mouseY >= marginTop && mouseY <= marginTop + graphHeight) {
    selectedIndex = findNearestIndex(mouseX);
    isDragging = true;
    updatePointFromMouse();
  }
}

void mouseDragged() {
  if (isDragging && selectedIndex >= 0 && selectedIndex < numPoints) {
    updatePointFromMouse();
  }
}

void mouseReleased() {
  isDragging = false;
  selectedIndex = -1;
}

int findNearestIndex(float mouseX) {
  int bestIndex = 0;
  float bestDist = Float.MAX_VALUE;
  for (int i = 0; i < numPoints; i++) {
    float x = indexToX(i);
    float d = abs(mouseX - x);
    if (d < bestDist) {
      bestDist = d;
      bestIndex = i;
    }
  }
  return bestIndex;
}

void updatePointFromMouse() {
  if (selectedIndex < 0 || selectedIndex >= numPoints) return;
  
  WeatherPoint wp = points[selectedIndex];
  
  // Map vertical drag to humidity change (0..1) inside graph
  float clampedY = constrain(mouseY, marginTop, marginTop + graphHeight);
  float humNorm = map(clampedY, marginTop + graphHeight, marginTop, 0, 1);
  wp.humNorm = constrain(humNorm, 0, 1);
  
  // Update real humidity value consistently
  wp.humidity = lerp(minHum, maxHum, wp.humNorm);
  
  // Re-send to PD if this is current point
  if (selectedIndex == currentIndex) {
    sendToPD(wp);
  }
}

/* ---------- OSC COMMUNICATION ---------- */

void sendToPD(WeatherPoint wp) {
  OscMessage msg = new OscMessage("/weather");
  
  msg.add(wp.tempNorm);  // 0: normalized temperature
  msg.add(wp.humNorm);   // 1: normalized humidity
  msg.add(wp.windNorm);  // 2: normalized wind speed
  msg.add(userGain);     // 3: master gain from UI
  
  oscP5.send(msg, pdAddress);
}
