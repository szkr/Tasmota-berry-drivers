import RelayPowersave
import JunctekKH
import PC1800
import Seplos

tasmota.add_driver(RelayPowersave(13, false))
tasmota.add_driver(RelayPowersave(12, false))
tasmota.add_driver(RelayPowersave(14, false))
tasmota.add_driver(RelayPowersave(27, false, 300))
tasmota.add_driver(RelayPowersave(26, false))
tasmota.add_driver(RelayPowersave(25, false))
tasmota.add_driver(RelayPowersave(33, false))
tasmota.add_driver(RelayPowersave(32, false))

tasmota.add_driver(JunctekKH(serial(23, 22, 115200, serial.SERIAL_8N1)))
tasmota.add_driver(Seplos(serial(17, 16, 9600, serial.SERIAL_8N1), 3))
tasmota.add_driver(PC1800(serial(19, 18, 9600, serial.SERIAL_8N1)))
