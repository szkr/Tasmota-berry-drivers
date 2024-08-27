# Tasmota-berry-drivers

A set of tasmota drivers for
- PC1800 solar charger aka Easun 4880
- Junctek KH battery monitor (Disable auto refresh in display's options or disconnect it to prevent collisions)
- Seplos BMS (My battery isn't fully compliant with the protocol specification i found so only some data is available)
- Relay with decreased holding pwm duty to save power

Everything is stable and working fine for weeks, at least for me ;)

Exposed read only entities (BMS=Seplos, Battery=Junctek)

![192 168 1 101_8123_lovelace_4](https://github.com/user-attachments/assets/683e2c58-d1b7-4e80-9229-6dc0848b9f3c)

For PC1800 there are also float voltage, absorbtion voltage, charging current and charging enabled read/write entities, but they are not assigned to the tasmota device because there's no such API in tasmota so they are added directly via MQTT


I used such RS485 converter modules

![image](https://github.com/user-attachments/assets/5b7288aa-46ff-4962-a155-a5e79033b855)

Converter for Junctek needs to be powered with 5v for stable communication, so coresponding ESP32 RX pin needs a voltage divider.


