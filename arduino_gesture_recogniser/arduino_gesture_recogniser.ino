#include <SoftwareSerial.h>
#include <Wire.h>
#include "paj7620.h"
#include "DFRobotDFPlayerMini.h"

// Create a SoftwareSerial object
static const uint8_t PIN_MP3_TX = 2; // Connects to module's RX 
static const uint8_t PIN_MP3_RX = 3; // Connects to module's TX 
SoftwareSerial softwareSerial(PIN_MP3_RX, PIN_MP3_TX);

SoftwareSerial BTSerial(10, 11); // RX | TX

DFRobotDFPlayerMini player;


#define GES_REACTION_TIME        500
#define GES_ENTRY_TIME           800
#define GES_QUIT_TIME            1000

void setup() {
    uint8_t error = 0;

    Serial.begin(9600);
    BTSerial.begin(9600);

    Serial.println("\nPAJ7620U2 TEST DEMO: Recognize 9 gestures.");
    error = paj7620Init(); // initialize Paj7620 registers
    if (error) {
        Serial.print("INIT ERROR,CODE:");
        Serial.println(error);
    } else {
        Serial.println("INIT OK");
    }
      softwareSerial.begin(9600);


      if (player.begin(softwareSerial)) {
        Serial.println("MP3 Player OK");

        // Set volume to maximum (0 to 30).
        player.volume(30);
        // Play the first MP3 file on the SD card
        player.play(1);
    } else {
        Serial.println("Connecting to DFPlayer Mini failed!");
    }

    Serial.println("Please input your gestures:\n");
}

void loop() {
    uint8_t data = 0, data1 = 0, error;

    error = paj7620ReadReg(0x43, 1, &data); // Read Bank_0_Reg_0x43/0x44 for gesture result.
    if (!error) {
        switch (data) { // When different gestures are detected, the variable 'data' will be set to different values by paj7620ReadReg(0x43, 1, &data).
            case GES_RIGHT_FLAG:
                delay(GES_ENTRY_TIME);
                paj7620ReadReg(0x43, 1, &data);
                if (data == GES_FORWARD_FLAG) {
                    sendGesture("Forward");
                    player.next(); // Play next track

                } else if (data == GES_BACKWARD_FLAG) {
                    sendGesture("Backward");
                    player.next(); 
                } else {
                    sendGesture("Right");
                    player.next(); 
                }
                break;
            case GES_LEFT_FLAG:
                delay(GES_ENTRY_TIME);
                paj7620ReadReg(0x43, 1, &data);
                if (data == GES_FORWARD_FLAG) {
                    sendGesture("Forward");
                } else if (data == GES_BACKWARD_FLAG) {
                    sendGesture("Backward");
                } else {
                    sendGesture("Left");
                    player.previous();
                }
                break;
            case GES_UP_FLAG:
                delay(GES_ENTRY_TIME);
                paj7620ReadReg(0x43, 1, &data);
                if (data == GES_FORWARD_FLAG) {
                    sendGesture("Forward");
                } else if (data == GES_BACKWARD_FLAG) {
                    sendGesture("Backward");
                } else {
                    sendGesture("Up");
                    player.volumeUp();
                }
                break;
            case GES_DOWN_FLAG:
                delay(GES_ENTRY_TIME);
                paj7620ReadReg(0x43, 1, &data);
                if (data == GES_FORWARD_FLAG) {
                    sendGesture("Forward");
                } else if (data == GES_BACKWARD_FLAG) {
                    sendGesture("Backward");
                } else {
                    sendGesture("Down");
                    player.volumeDown();
                }
                break;
            case GES_FORWARD_FLAG:
                sendGesture("Forward");
                break;
            case GES_BACKWARD_FLAG:
                sendGesture("Backward");
                break;
            case GES_CLOCKWISE_FLAG:
                sendGesture("Clockwise");
                player.start();
                break;
            case GES_COUNT_CLOCKWISE_FLAG:
                sendGesture("anti-clockwise");
                player.pause();
                break;
            default:
                paj7620ReadReg(0x44, 1, &data1);
                if (data1 == GES_WAVE_FLAG) {
                    sendGesture("Wave");
                }
                break;
        }
    }
    delay(100);
}

void sendGesture(const char* gesture) {
    Serial.println(gesture);
    BTSerial.println(gesture);
}