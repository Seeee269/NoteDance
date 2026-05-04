// =====================================================================
// CMLS Project - Accelerometer -> Serial
// Sensor: MMA7361 (analog, 3-axis).
// Output format: "x,y,z\n", values in g, one line every SAMPLE_MS.
//
// Hardware notes (most SparkFun-style red MMA7361 breakouts):
// - VCC -> 3.3V on Arduino (NOT 5V; the breakout has its own 3.3V LDO,
//   but driving VIN with 5V is only safe if the board has level
//   shifting on the digital pins. If unsure, use 3.3V).
// - GND -> GND.
// - X, Y, Z -> three analog inputs on the Arduino (default A0, A1, A2).
// - SL (sleep) -> any digital pin held HIGH; sensor is asleep when LOW.
// - GS (g-select) -> tie to GND for +-1.5g (more sensitive, default
//   here) or HIGH for +-6g (more headroom but coarser).
// - 0G  -> unused for streaming (digital "free fall" detect).
// - ST  -> tie to GND (self-test off).
//
// If you change supply voltage or g-range, also update VCC and
// SENSITIVITY below, and ACCEL_RANGE_G on the Python bridge side.
// =====================================================================

const int PIN_X     = A0;
const int PIN_Y     = A1;
const int PIN_Z     = A2;
const int PIN_SLEEP = 4;          // digital, HIGH = sensor active

const float VCC          = 5.0;   // Arduino analog reference (5.0 for Uno/Nano)
const float ZERO_G_VOLTS = 1.65;  // MMA7361 outputs Vcc/2 at rest; trim per axis below if needed
const float SENSITIVITY  = 0.800; // V/g  (datasheet typ. for +-1.5g range; use 0.206 for +-6g)

// Per-axis trim if the board does not read 0,0,1g exactly when flat.
// Tweak after a quick sanity print on the serial monitor.
const float OFFSET_X = 0.0;
const float OFFSET_Y = 0.0;
const float OFFSET_Z = 0.0;

const unsigned long SAMPLE_MS = 20;   // 50 Hz
unsigned long lastSample = 0;

float readAxisG(int pin, float offset) {
  int raw = analogRead(pin);                    // 0..1023 over 0..VCC
  float volts = raw * (VCC / 1023.0);
  return ((volts - ZERO_G_VOLTS) / SENSITIVITY) - offset;
}

void setup() {
  Serial.begin(115200);
  while (!Serial) { ; }

  pinMode(PIN_SLEEP, OUTPUT);
  digitalWrite(PIN_SLEEP, HIGH);   // wake the sensor
  delay(50);                        // datasheet wake time is ~1 ms; be generous

  // Use the default analog reference (DEFAULT == AVcc on Uno/Nano).
  // If you tie AREF to 3.3V externally, call analogReference(EXTERNAL)
  // here AND set VCC = 3.3 above.
}

void loop() {
  unsigned long now = millis();
  if (now - lastSample < SAMPLE_MS) return;
  lastSample = now;

  float gx = readAxisG(PIN_X, OFFSET_X);
  float gy = readAxisG(PIN_Y, OFFSET_Y);
  float gz = readAxisG(PIN_Z, OFFSET_Z);

  Serial.print(gx, 4);
  Serial.print(',');
  Serial.print(gy, 4);
  Serial.print(',');
  Serial.println(gz, 4);
}
