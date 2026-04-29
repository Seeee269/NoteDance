// =====================================================================
// CMLS Project — Accelerometer → Serial
// 默认用 MPU6050（I2C，最常见的便宜模块）。如果你们用别的传感器，
// 只需要替换 setup() 里的初始化和 loop() 里读三轴的部分，
// 串口输出格式保持 "x,y,z\n"（单位 g） 即可。
// =====================================================================

#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

Adafruit_MPU6050 mpu;

const float G = 9.80665f;          // m/s^2 → g 换算
const unsigned long SAMPLE_MS = 20; // 50 Hz

unsigned long lastSample = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial) { ; }

  Wire.begin();
  if (!mpu.begin()) {
    // 卡死并报错，方便排查接线
    while (1) {
      Serial.println("ERR: MPU6050 not found, check wiring");
      delay(1000);
    }
  }

  mpu.setAccelerometerRange(MPU6050_RANGE_4_G);  // ±4g 给小车晃动留余量
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);    // 板载低通，去抖
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
