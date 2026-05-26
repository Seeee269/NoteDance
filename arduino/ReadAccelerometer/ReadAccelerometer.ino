#include <Arduino_LSM6DS3.h>
#include <WiFiNINA.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>

const char* ssid = "Polizia Municipale";
const char* password = "franco126";

IPAddress targetIp(172, 20, 10, 6);   // IP del PC (Linux / destinazione)
const unsigned int targetPort = 9001;  // porta del plugin JUCE
const unsigned int scPort = 57120;     // porta di SuperCollider (default)

WiFiUDP udp;

const int ROTARY_PIN = A0; 

// --- VARIABILI PER IL FILTRO PASSA-BASSO ---
const float accelAlpha = 0.40f; 
const float rotaryAlpha = 0.15f; 

// Memoria per i valori filtrati
float smoothedAx = 0.0f;
float smoothedAy = 0.0f;
float smoothedRotary = 0.0f;

void setup() {
  Serial.begin(9600);
  while (!Serial) {}

  if (!IMU.begin()) {
    Serial.println("Errore: IMU non inizializzata");
    while (1) {}
  }

  Serial.print("Connessione a WiFi");
  int status = WiFi.begin(ssid, password);
  while (status != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    status = WiFi.status();
  }
  Serial.println();
  Serial.println("WiFi connesso");

  // Inizia UDP senza bind su porta specifica (ephemeral)
  udp.begin(0); 
  Serial.print("IP Arduino: ");
  Serial.println(WiFi.localIP());

  // Inizializzazione per evitare partenze da zero del rotary
  smoothedRotary = analogRead(ROTARY_PIN);
}

void loop() {
  // --- 1. LETTURA, FILTRAGGIO E INVIO ROTARY SENSOR ---
  int rawRotary = analogRead(ROTARY_PIN); 
  smoothedRotary = (rotaryAlpha * rawRotary) + ((1.0f - rotaryAlpha) * smoothedRotary);
  
  OSCMessage msgRotary("/rotary");
  msgRotary.add((float)smoothedRotary); 

  // invio a JUCE (targetPort)
  udp.beginPacket(targetIp, targetPort);
  msgRotary.send(udp);
  udp.endPacket();

  // invio a SuperCollider (scPort) - copia aggiuntiva
  udp.beginPacket(targetIp, scPort);
  msgRotary.send(udp);
  udp.endPacket();

  msgRotary.empty();

  // --- 2. LETTURA, FILTRAGGIO E INVIO ACCELEROMETRO ---
  float rawAx = 0.0f;
  float rawAy = 0.0f;
  float rawAz = 0.0f;

  if (IMU.accelerationAvailable()) {
    IMU.readAcceleration(rawAx, rawAy, rawAz);

    // Applica il filtro passa-basso agli assi X e Y
    smoothedAx = (accelAlpha * rawAx) + ((1.0f - accelAlpha) * smoothedAx);
    smoothedAy = (accelAlpha * rawAy) + ((1.0f - accelAlpha) * smoothedAy);

    OSCMessage msgAccel("/accel");
    msgAccel.add(smoothedAx); 
    msgAccel.add(smoothedAy);

    // invio a JUCE (targetPort)
    udp.beginPacket(targetIp, targetPort);
    msgAccel.send(udp);
    udp.endPacket();

    // invio a SuperCollider (scPort) - copia aggiuntiva
    udp.beginPacket(targetIp, scPort);
    msgAccel.send(udp);
    udp.endPacket();

    msgAccel.empty();

    // --- 3. DEBUG SERIALE COMPLETO ---
    Serial.print("Rotary: ");
    Serial.print(smoothedRotary);
    Serial.print("  |  Accel X: ");
    Serial.print(smoothedAx);
    Serial.print("  Y: ");
    Serial.println(smoothedAy);
  } else {
    Serial.print("Rotary: ");
    Serial.println(smoothedRotary);
  }

  delay(100);
}