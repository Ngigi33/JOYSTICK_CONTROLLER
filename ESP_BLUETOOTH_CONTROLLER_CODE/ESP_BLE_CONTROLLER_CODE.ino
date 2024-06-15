#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
//#include <BLE2a05.h>
#include <Wire.h>


#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLEName "S.L.A.M"
bool deviceConnected = false;
bool oldDeviceConnected = false;
//BLECharacteristic *pCharacteristicRX;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    Serial.println("Client Connected!");
  };

  void onDisconnect(BLEServer *pServer) {
    Serial.println("Client disconnecting... Waiting for new connection");
    pServer->startAdvertising();  // restart advertising
  }
};


//BLE RX callback
class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristicTX) {
    Serial.print("Receiving.........");
    uint8_t *data = pCharacteristicTX->getData();
    //std::string rxValue = pCharacteristicTX->getValue();
    int size = pCharacteristicTX->getLength();

    if (size > 0) {
      Serial.println("*********");
      Serial.print("CMD:");
      Serial.print(data[0]);
      Serial.print("     Value:");
      Serial.println(data[1]);


      // for (int i = 0; i < size; i++)
      //   Serial.print(data[i]);

      // Serial.println();
      Serial.println("*********");
    }
  }
};


void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.println("Starting BLE work");




  // create BLE DEVICE
  BLEDevice::init(BLEName);
  Serial.printf("BLE Server Mac Address: %s\n", BLEDevice::getAddress().toString().c_str());



  //CREATE BLE Server
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());



  //CREATE A SERVICE
  BLEService *pService = pServer->createService(SERVICE_UUID);
  //Serial.print(pService);



  //CREATE a BLE CHARACTERISTIC FOR SENDING
  BLECharacteristic *pCharacteristicTX = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristicTX->addDescriptor(new BLE2902());
  pCharacteristicTX->setValue("Hello World");




  //Create a BLE CHARACTERISTIC FOR RECEIVING
  BLECharacteristic *pCharacteristicRX = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE);
  pCharacteristicRX->setCallbacks(new MyCallbacks());
  pCharacteristicRX->addDescriptor(new BLE2902());





  //START THE SERVICE
  pService->start();


  // Start advertising
  // BLEAdvertising *pAdvertising = pServer->getAdvertising();
  // pAdvertising->start();


  // pServer->getAdvertising()->start();
  // Serial.println("Waiting a client connection to notify...");

  // //START ADVERTISING
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x00);  // set value to 0x00 to not advertise this parameter
  BLEDevice::startAdvertising();
  Serial.println("Waiting a client connection to notify...");
}

void loop() {
  // put your main code here, to run repeatedly:
  //pCharacteristicRX->setCallbacks(new Received_Callback());
  delay(1000);
}
