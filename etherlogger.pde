#include <SD.h>

#include <Client.h>
#include <Ethernet.h>
#include <Server.h>
#include <Udp.h>

#if defined(ARDUINO) && ARDUINO > 18
#include <SPI.h>
#endif
#include <Ethernet.h>

#include <EthernetDHCP.h>
#include <EthernetDNS.h>
//#include <EthernetBonjour.h>
#include <Time.h> 

#include "decoders.h"

//const char* bonjour_hostname = "datalogger";
const char* ntp_host = "uk.pool.ntp.org";
byte mac[] = { 0x90, 0xA2, 0xDA, 0x00, 0x24, 0x7F };
char log_file[16];
byte ntp_server_ip[] = {0x0,0x0,0x0,0x0};

Server webService(80);

float CT1, CT2, CT3;
int deviceID;
time_t timestamp;

OregonDecoderV2 orscV2;

#define PORT 2

volatile word pulse;

#if defined(__AVR_ATmega1280__)
void ext_int_1(void) {
#else
ISR(ANALOG_COMP_vect) {
#endif
    static word last;
    // determine the pulse length in microseconds, for either polarity
    pulse = micros() - last;
    last += pulse;
}

void setup() {
   Serial.begin(115200);
   
  pinMode(10, OUTPUT);                       // set the SS pin as an output (necessary!)
  digitalWrite(10, HIGH);                    // but turn off the W5100 chip!
  SD.begin(4);
   
   EthernetDHCP.begin(mac, 1);
}

#define BUFFER_SIZE 100

void loop() {
 static DhcpState prevState = DhcpStateNone;
  static unsigned long prevTime = 0;
  static byte waiting_for_ntp_ip = true;
  static int cycleCounter = 0;
  char clientline[BUFFER_SIZE];
  int index = 0;
  static byte broadcastCounter = 0;
  
  if (!waiting_for_ntp_ip) {datalog();cycleCounter++;}
  if (waiting_for_ntp_ip || ((cycleCounter % (0x1 << 15)) == 0))
  {
//    if (!waiting_for_ntp_ip) {
//      Serial.println("dhcp");
//    }
  DhcpState state = EthernetDHCP.poll();

  if (!waiting_for_ntp_ip) {
    // check web service
    Client client = webService.available();
    if (client) {
       // an http request ends with a blank line
  
    index = 0;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        
        if (c != '\n' && c != '\r') {
          clientline[index] = c;
          index++;
          if (index >= BUFFER_SIZE) index = BUFFER_SIZE-1;
          continue;
        }
        
        clientline[index] = 0;
        
        client.println("HTTP/1.1 200 OK");
        char *substr;
        if ((substr = strstr(clientline, "log/")) != 0) {
          substr += 3;
          char *end_request;
          if (end_request = strstr(clientline, " HTTP/")) {
            end_request[0] = '\0';
          }
          if (substr[1] == '\0') {
            ListFiles(client, LS_SIZE);
          } else {
            if (substr[1] == 't') {
              substr = log_file;
            }
            Serial.println(substr);
            // dump the log
            client.println("Content-Type: text/csv");
            client.println();
            File logf = SD.open(substr, FILE_READ);
            if (logf) {
              int c;
              while ((c = logf.read()) >= 0) {
                client.print((char) c);
              }
              logf.close();
            }
          }
        } else {
          Serial.println("latest");

          client.println("Content-Type: text/html");
          client.println();
          client.print(timestamp);client.print(',');
          client.print(deviceID);client.print(',');
          client.print(CT1);client.print(',');
          client.print(CT2);client.print(',');
          client.print(CT3);client.println();
        }
        
       break;
      }
    }
    // give the web browser time to receive the data
    delay(10);
    // close the connection:
    client.stop();
    }
  }

  if (prevState != state) {
    Serial.println();

    switch (state) {
      case DhcpStateDiscovering:
        Serial.print("dhcpdisc.");
        break;
      case DhcpStateRequesting:
        Serial.print("dhcpreq.");
        break;
      case DhcpStateRenewing:
        Serial.print("dhcpren.");
        break;
      case DhcpStateLeased: {
        Serial.println("dhcpok");

        const byte* ipAddr = EthernetDHCP.ipAddress();
        const byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
        const byte* dnsAddr = EthernetDHCP.dnsIpAddress();

        Serial.print("ip=");
        Serial.println(ip_to_str(ipAddr));

        Serial.print("gw=");
        Serial.println(ip_to_str(gatewayAddr));

        Serial.print("dns=");
        Serial.println(ip_to_str(dnsAddr));

        Serial.println('\n');
    
        EthernetDNS.setDNSServer(dnsAddr);
        
//        EthernetBonjour.begin(bonjour_hostname);
        
        waiting_for_ntp_ip = true;
        
        break;
      }
    }
  } else if (state != DhcpStateLeased && millis() - prevTime > 300) {
     prevTime = millis();
     Serial.print('.'); 
  } else if (state == DhcpStateLeased) {
//    EthernetBonjour.run();
    
    if (waiting_for_ntp_ip) 
   {
     
      DNSError err = EthernetDNS.resolveHostName(ntp_host, ntp_server_ip);
      
      if (DNSSuccess == err) {
        Serial.print("NTP IP address is ");
        Serial.print(ip_to_str(ntp_server_ip));
        Serial.println(".");
        
        waiting_for_ntp_ip = false;
        
        //set up ntp
        Udp.begin(35353);
         setSyncProvider(getNtpTime);
         setSyncInterval(1800); // resync clock every half-hour
         while(timeStatus()== timeNotSet) {
           Serial.print('.');
           delay(500);
         }
         
         Serial.println("Starting web service");
         webService.begin();
      } else if (DNSTimedOut == err) {
        Serial.println("Timed out.");
      } else if (DNSNotFound == err) {
        Serial.println("Does not exist.");
      } else {
        Serial.print("Failed with error code ");
        Serial.print((int)err, DEC);
        Serial.println(".");
      }
   } else {
     broadcastCounter++;
  if(broadcastCounter > 20) {
    broadcast_state();
    broadcastCounter = 0;
  }
   }
  }
 prevState = state;
  }
}
void printDigits(int digits){
  // utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits);
}
void datalog() {
  
  static byte dl_enabled = false;
  if (!dl_enabled) {
      pinMode(13 + PORT, INPUT);  // use the AIO pin
    digitalWrite(13 + PORT, 1); // enable pull-up

    // use analog comparator to switch at 1.1V bandgap transition
    ACSR = _BV(ACBG) | _BV(ACI) | _BV(ACIE);

    // set ADC mux to the proper port
    ADCSRA &= ~ bit(ADEN);
    ADCSRB |= bit(ACME);
    ADMUX = PORT - 1;
    dl_enabled = true;
  }

  cli();
  word p = pulse;
  pulse = 0;
  sei();
  
  if (p != 0) {
    if (orscV2.nextPulse(p)) {
      report(&orscV2);
    }
  }
}

void print_and_log(const time_t stamp, const int id, const float v1, const float v2, const float v3, File &output) {
  Serial.print(stamp);
  output.print(stamp);
  Serial.print(',');
  output.print(',');
  Serial.print(id);
  output.print(id);
  Serial.print(',');
  output.print(',');
  Serial.print(v1);
  output.print(v1);
  Serial.print(',');
  output.print(',');
  Serial.print(v2);
  output.print(v2);
  Serial.print(',');
  output.print(',');
  Serial.print(v3);
  output.print(v3);
  Serial.println();
  output.println();
}

int log_day = -1;
int log_month;

void report(Decoder *decoder) {
    byte pos;
    const byte* data = decoder->getData(pos);
    if (
      (data[0] == 0xEA) &&
      (
        ((data[1] & 0xF0) == 0x00) ||
        ((data[1] & 0xF0) == 0x20)
      )) {
        

        timestamp = now();
        
        // compute day of year
        int new_log_day = day(timestamp);
        if (new_log_day != log_day) {

          log_month = month(timestamp);
          // create new log file
          sprintf(log_file, "/%d-%d.csv\0", new_log_day, log_month);
          if (log_day != -1) SD.remove(log_file);
          log_day = new_log_day;
          Serial.println(log_file);
        }
        File output = SD.open(log_file, FILE_WRITE);
        
        CT1 = (data[3] + (data[4] & 0x3) * 256) / (float) 10;
        CT2 = (((data[4]>>2) & 0x3F) + (data[5] & 0xF) * 64) / 10;
        CT3 = (((data[5]>>4) & 0xF) + (data[6] & 0x3F) * 16) / 10;
        
        deviceID = data[2];
        print_and_log(timestamp, deviceID, CT1, CT2, CT3, output);
        output.close();
        broadcast_state();
      }
 
    decoder->resetDecoder();

}

const char* ip_to_str(const uint8_t* ipAddr)
{
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
}

const int NTP_PACKET_SIZE=48; // NTP time stamp is in the first 48 bytes of the message

byte packetBuffer[ NTP_PACKET_SIZE]; //buffer to hold incoming and outgoing packets 
byte broadcast[]={0xFF,0xFF,0xFF,0xFF};
//broadcast CT1, CT2, CT3
void broadcast_state() {
  memcpy(packetBuffer, &timestamp, sizeof(timestamp));
  memcpy(packetBuffer+sizeof(timestamp), &deviceID, sizeof(deviceID));
  memcpy(packetBuffer+sizeof(timestamp)+sizeof(deviceID), &CT1, sizeof(CT1));
  memcpy(packetBuffer+sizeof(timestamp)+sizeof(deviceID)+sizeof(CT1), &CT2, sizeof(CT2));
  memcpy(packetBuffer+sizeof(timestamp)+sizeof(deviceID)+sizeof(CT1)+sizeof(CT2), &CT3, sizeof(CT3));
  Udp.sendPacket(packetBuffer, 3 * sizeof(float) + sizeof(int) + sizeof(time_t), broadcast,35353);
}

unsigned long getNtpTime()
{
  Serial.print("Requesting time from server");
  Serial.println();
  sendNTPpacket(ntp_server_ip);
  Serial.println("Awaiting reply...");
  Serial.println();
  delay(2000);

  if ( Udp.available() ) {  
    Udp.readPacket(packetBuffer,NTP_PACKET_SIZE);  // read the packet into the buffer

    //the timestamp starts at byte 40 of the received packet and is four bytes,
    // or two words, long. First, esxtract the two words:

    unsigned long highWord = word(packetBuffer[40], packetBuffer[41]);
    unsigned long lowWord = word(packetBuffer[42], packetBuffer[43]);  
    // combine the four bytes (two words) into a long integer
    // this is NTP time (seconds since Jan 1 1900):
    unsigned long secsSince1900 = highWord << 16 | lowWord;  
    const unsigned long seventyYears = 2208988800UL;     
    // subtract seventy years:
    Serial.println("Got time from server");
    return secsSince1900 - seventyYears;  
  }
  
  Serial.println("Time server did not respond");
  
  return 0; // return 0 if unable to get the time
}

unsigned long sendNTPpacket(byte *address)
{
  // set all bytes in the buffer to 0
  memset(packetBuffer, 0, NTP_PACKET_SIZE); 
  // Initialize values needed to form NTP request
  // (see URL above for details on the packets)
  packetBuffer[0] = 0b11100011;   // LI, Version, Mode
  packetBuffer[1] = 0;     // Stratum, or type of clock
  packetBuffer[2] = 6;     // Polling Interval
  packetBuffer[3] = 0xEC;  // Peer Clock Precision
  // 8 bytes of zero for Root Delay & Root Dispersion
  packetBuffer[12]  = 49; 
  packetBuffer[13]  = 0x4E;
  packetBuffer[14]  = 49;
  packetBuffer[15]  = 52;

  // all NTP fields have been given values, now
  // you can send a packet requesting a timestamp: 		   
  Udp.sendPacket( packetBuffer,NTP_PACKET_SIZE,  address, 123); //NTP requests are to port 123
}

void ListFiles(Client client, uint8_t flags) {
  // This code is just copied from SdFile.cpp in the SDFat library
  // and tweaked to print to the client output in html!
  dir_t p;
  
   client.println("Content-Type: text/html");
   client.println();
          
          
  client.println("<h2>Log</h2>");
  
  SdFile root;
  root.openRoot(&(SD.volume));
  
  root.rewind();
  client.println("<ul>");
  while (root.readDir(p) > 0) {
    // done if past last used entry
    if (p.name[0] == DIR_NAME_FREE) break;

    // skip deleted entry and entries for . and  ..
    if (p.name[0] == DIR_NAME_DELETED || p.name[0] == '.') continue;

    // only list subdirectories and files
    if (!DIR_IS_FILE_OR_SUBDIR(&p)) continue;

    // print any indent spaces
    client.print("<li><a href=\"");
    for (uint8_t i = 0; i < 11; i++) {
      if (p.name[i] == ' ') continue;
      if (i == 8) {
        client.print('.');
      }
      client.print(p.name[i]);
    }
    client.print("\">");
    
    // print file name with possible blank fill
    for (uint8_t i = 0; i < 11; i++) {
      if (p.name[i] == ' ') continue;
      if (i == 8) {
        client.print('.');
      }
      client.print(p.name[i]);
    }
    
    client.print("</a>");
    
    if (DIR_IS_SUBDIR(&p)) {
      client.print('/');
    }

    // print modify date/time if requested
    
    // print size if requested
    if (!DIR_IS_SUBDIR(&p) && (flags & LS_SIZE)) {
      client.print(' ');
      client.print(p.fileSize);
    }
    client.println("</li>");
  }
  client.println("</ul>");
  
  root.close();
}
