// =====================================================================
// CMLS Project — Accelerometer → Serial
// Default sensor: MPU6050 (I2C, the cheapest and most common module).
// To use a different sensor, swap the init in setup() and the read in
// loop(); keep the serial output format "x,y,z\n" (units of g) so the
// Python bridge does not need to change.
// =====================================================================

#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

Adafruit_MPU6050 mpu;

const float G = 9.80665f;            // m/s^2 -> g
const unsigned long SAMPLE_MS = 20;  // 50 Hz

unsigned long lastSample = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial) { ; }

  Wire.begin();
  if (!mpu.begin()) {
    // Hang and report so wiring problems are obvious.
    while (1) {
      Serial.println("ERR: MPU6050 not found, check wiring");
      delay(1000);
    }
  }

  mpu.setAccelerometerRange(MPU6050_RANGE_4_G);  // headroom for shaking
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);    // on-chip low-pass
}

void loop() {
  unsigned long now = millis();
  if (now - lastSample < SAMPLE_MS) return;
  lastSample = now;

  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  float gx = a.acceleration.x / G;
  float gy = a.acceleration.y / G;
  float gz = a.acceleration.z / G;

  Serial.print(gx, 4);
  Serial.print(',');
  Serial.print(gy, 4);
  Serial.print(',');
  Serial.println(gz, 4);
}
