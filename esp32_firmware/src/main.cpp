/*
 * DoseGrind Connect companion firmware - HARDWARE-DEPENDENT STARTING IMPLEMENTATION.
 * Not preserved from tested source (none was available); not compiled or bench-tested here.
 * This is a monitor/UI device only. It MUST NOT control mixer mains, motor, speed, or interlocks.
 */
#include <Arduino.h>
#include <Wire.h>
#include <NimBLEDevice.h>
#include <PZEM004Tv30.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ArduinoJson.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

static constexpr uint8_t OLED_SDA=21, OLED_SCL=22, DS_DATA=4;
static constexpr uint8_t PZEM_RX=16, PZEM_TX=17, BUTTON_A=26, BUTTON_B=27, BUZZER=25;
static constexpr char DEVICE_NAME[]="DOSEGRIND_ESP32";
static constexpr char SERVICE_UUID[]="12345678-1234-1234-1234-123456789000";
static constexpr char LIVE_UUID[]="12345678-1234-1234-1234-123456789001";
static constexpr char STATUS_UUID[]="12345678-1234-1234-1234-123456789002";
static constexpr char CONFIG_UUID[]="12345678-1234-1234-1234-123456789003";
static constexpr uint32_t TELEMETRY_MS=1000, SESSION_IDLE_MS=12000;
// Provisional alert setting only. Validate for the final enclosure/sensor; not a certified safety limit.
static float temperatureAlertC=70.0f;
static float calibratedPowerThresholdW=20.0f; // MUST calibrate with actual appliance/sensor/module.
static uint32_t sessionIdleMs=SESSION_IDLE_MS;

HardwareSerial pzemSerial(2);
PZEM004Tv30 pzem(pzemSerial, PZEM_RX, PZEM_TX);
OneWire oneWire(DS_DATA);
DallasTemperature dallas(&oneWire);
Adafruit_SSD1306 display(128,64,&Wire,-1);
NimBLECharacteristic *liveCharacteristic=nullptr, *statusCharacteristic=nullptr;
uint32_t lastTelemetry=0, lastActiveMs=0, sessionStartMs=0;
uint64_t sessionCount=0;
bool sessionActive=false, oledOk=false;
float tempC=NAN, voltageV=NAN, currentA=NAN, powerW=NAN, energyWh=NAN, frequencyHz=NAN;
String sensorStatus="STARTING";

class ConfigCallbacks: public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c, NimBLEConnInfo&) override {
    const std::string raw=c->getValue();
    JsonDocument doc;
    if (deserializeJson(doc, raw) || !doc["command"].is<const char*>()) return;
    const char *cmd=doc["command"];
    // Strict UI/status/config allowlist. No motor, speed, relay, or mains switching commands exist.
    if (!strcmp(cmd,"request_status")) return;
    if (!strcmp(cmd,"device_info")) return;
    if (!strcmp(cmd,"set_oled_page")) return;
    if (!strcmp(cmd,"reset_session_energy")) { sessionCount=0; return; }
    if (!strcmp(cmd,"set_time")) return; // accepted as a UI hint in a future implementation; no RTC set here
    if (!strcmp(cmd,"set_thresholds")) {
      if (doc["power_threshold_w"].is<float>()) {
        const float n=doc["power_threshold_w"].as<float>(); if (n>=1 && n<=2000) calibratedPowerThresholdW=n;
      }
      if (doc["idle_timeout_ms"].is<uint32_t>()) {
        const uint32_t n=doc["idle_timeout_ms"].as<uint32_t>(); if (n>=3000 && n<=120000) sessionIdleMs=n;
      }
    }
  }
};

static String liveJson() {
  JsonDocument d;
  d["data_mode"]="LIVE";
  d["timestamp"]=(uint32_t)(millis()/1000);
  d["uptime_ms"]=millis();
  if (isfinite(tempC)) d["temperature"]=tempC; else d["temperature"]=nullptr;
  if (isfinite(voltageV)) d["voltage"]=voltageV; else d["voltage"]=nullptr;
  if (isfinite(currentA)) d["current"]=currentA; else d["current"]=nullptr;
  if (isfinite(powerW)) d["power"]=powerW; else d["power"]=nullptr;
  if (isfinite(energyWh)) d["energy_wh"]=energyWh; else d["energy_wh"]=nullptr;
  d["session_energy_wh"]=nullptr; // PZEM cumulative energy needs reset/baseline semantics validated before exposing.
  if (isfinite(frequencyHz)) d["frequency"]=frequencyHz; else d["frequency"]=nullptr;
  d["mixer_status"]=sessionActive?"RUNNING":"IDLE";
  d["sensor_status"]=sensorStatus;
  String out; serializeJson(d,out); return out;
}
static void pollSensors() {
  dallas.requestTemperatures();
  const float t=dallas.getTempCByIndex(0);
  tempC=(t==DEVICE_DISCONNECTED_C || t < -55 || t > 125)?NAN:t;
  const float v=pzem.voltage(), a=pzem.current(), w=pzem.power(), kwh=pzem.energy(), hz=pzem.frequency();
  voltageV=isfinite(v)?v:NAN; currentA=isfinite(a)?a:NAN; powerW=isfinite(w)?w:NAN;
  energyWh=isfinite(kwh)?kwh*1000.0f:NAN; frequencyHz=isfinite(hz)?hz:NAN;
  sensorStatus=(isfinite(tempC)&&isfinite(powerW)&&isfinite(voltageV)&&isfinite(currentA))?"OK":"ERROR";
  const uint32_t now=millis();
  if (isfinite(powerW) && powerW>=calibratedPowerThresholdW) {
    if (!sessionActive) {sessionActive=true;sessionStartMs=now;sessionCount++;}
    lastActiveMs=now;
  } else if (sessionActive && (uint32_t)(now-lastActiveMs)>=sessionIdleMs) sessionActive=false;
  // Local alert persists independently of phone/BLE. This is provisional awareness, NOT mixer protection.
  digitalWrite(BUZZER,(isfinite(tempC)&&tempC>=temperatureAlertC)?HIGH:LOW);
}
static void drawOled() {
  if (!oledOk) return;
  display.clearDisplay(); display.setTextColor(SSD1306_WHITE); display.setTextSize(1); display.setCursor(0,0);
  display.println("DOSEGRIND MONITOR"); display.println(sensorStatus);
  display.print("Temp: "); if(isfinite(tempC)){display.print(tempC,1);display.println(" C");} else display.println("--");
  display.print("Power: "); if(isfinite(powerW)){display.print(powerW,0);display.println(" W");} else display.println("--");
  display.print("Voltage: "); if(isfinite(voltageV)){display.print(voltageV,0);display.println(" V");} else display.println("--");
  display.print("Session: "); display.println(sessionActive?"ACTIVE":"IDLE");
  display.println("Mixer remains manual"); display.display();
}
static void updateStatus() {
  if (!statusCharacteristic) return;
  JsonDocument d; d["device_name"]=DEVICE_NAME; d["sensor_status"]=sensorStatus; d["mixer_status"]=sessionActive?"RUNNING":"IDLE";
  d["uptime_ms"]=millis(); d["power_threshold_w"]=calibratedPowerThresholdW; d["idle_timeout_ms"]=sessionIdleMs;
  d["warning"]="Temperature alert is provisional; not certified protection.";
  String out; serializeJson(d,out); statusCharacteristic->setValue(out.c_str()); statusCharacteristic->notify();
}
void setup() {
  Serial.begin(115200);
  pinMode(BUZZER,OUTPUT); digitalWrite(BUZZER,LOW);
  pinMode(BUTTON_A,INPUT_PULLUP); pinMode(BUTTON_B,INPUT_PULLUP);
  Wire.begin(OLED_SDA,OLED_SCL); oledOk=display.begin(SSD1306_SWITCHCAPVCC,0x3C); dallas.begin();
  pzemSerial.begin(9600,SERIAL_8N1,PZEM_RX,PZEM_TX);
  NimBLEDevice::init(DEVICE_NAME);
  NimBLEDevice::setMTU(247);
  NimBLEServer *server=NimBLEDevice::createServer();
  NimBLEService *service=server->createService(SERVICE_UUID);
  liveCharacteristic=service->createCharacteristic(LIVE_UUID,NIMBLE_PROPERTY::READ|NIMBLE_PROPERTY::NOTIFY);
  statusCharacteristic=service->createCharacteristic(STATUS_UUID,NIMBLE_PROPERTY::READ|NIMBLE_PROPERTY::NOTIFY);
  NimBLECharacteristic *config=service->createCharacteristic(CONFIG_UUID,NIMBLE_PROPERTY::WRITE|NIMBLE_PROPERTY::WRITE_NR);
  config->setCallbacks(new ConfigCallbacks());
  service->start(); NimBLEAdvertising *advertising=NimBLEDevice::getAdvertising(); advertising->addServiceUUID(SERVICE_UUID); advertising->start();
  sensorStatus="STARTING"; drawOled();
}
void loop() {
  const uint32_t now=millis();
  if ((uint32_t)(now-lastTelemetry)>=TELEMETRY_MS) {
    lastTelemetry=now; pollSensors();
    if(liveCharacteristic){String payload=liveJson(); liveCharacteristic->setValue(payload.c_str()); liveCharacteristic->notify();}
    updateStatus(); drawOled();
  }
  // Buttons reserved for OLED page/status UI; they never operate the mixer.
  delay(5);
}
