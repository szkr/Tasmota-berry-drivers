import string
import mqtt
import json
import Modbus_message

class PC1800
    static var charger_states = ['Initalization', 'Selftest', 'Working', 'Stopped']
    static var mppt_states = ['Stopped', 'MPPT', 'Current limiting']
    static var charging_stages = ['Stopped', 'Absorb', 'Float', 'Equalization']
    static var relay_states = ['OFF', 'ON']
    var ser, message_queue
    var state_received, charger_state, mppt_state, charging_stage, pv_voltage, battery_voltage, charging_current, charging_power, radiator_temperature, external_temperature, battery_relay, pv_relay, error_message, warning_message, accumulated_energy, working_time
    var settings_received, charger_enabled, float_voltage, absorption_voltage, max_charging_current, cv_charging_time
    var sensors_published, mac_addr
    var settings_counter
    var charger_enabled_idx
    var debug
    
    def init(ser, debug)
        print("PC1800: Init")
        self.ser = ser
        self.message_queue = []
        self.mac_addr = string.tr(tasmota.wifi('mac'), ':', '')
        self.settings_counter = 8
        self.debug = debug != nil ? debug : false
        if !self.ser
            print("PC1800: Couldn't get serial")
        end
        self.charger_enabled_idx = tasmota.global.devices_present
        tasmota.global.devices_present += 1
    end

    def every_second()
        if !self.ser return nil end
        var bts = self.ser.read()
        var msg = Modbus_message()

        if msg.from_bytes(bts) && msg.amount == 24
            self.state_received = true
            self.charger_state = PC1800.charger_states[msg.register_values[0]]
            self.mppt_state = PC1800.mppt_states[msg.register_values[1]]
            self.charging_stage = PC1800.charging_stages[msg.register_values[2]]
            self.pv_voltage = msg.register_values[4] / 10.0
            self.battery_voltage = msg.register_values[5] / 10.0
            self.charging_current = msg.register_values[6] / 10.0
            self.charging_power = msg.register_values[7]
            self.radiator_temperature = msg.get_register(8, true)
            self.external_temperature = msg.register_values[9]
            self.battery_relay = PC1800.relay_states[msg.register_values[10]]
            self.pv_relay = PC1800.relay_states[msg.register_values[11]]
            self.accumulated_energy = msg.register_values[16] * 1000 + msg.register_values[17] / 10.0
        end
        if msg.from_bytes(bts) && msg.amount == 26
            self.settings_received = true
            self.charger_enabled = msg.register_values[0] == 1 ? true : false
            self.float_voltage = msg.register_values[2] / 10.0
            self.absorption_voltage = msg.register_values[3] / 10.0
            self.max_charging_current = msg.register_values[7] / 10.0
            self.cv_charging_time = msg.register_values[15]


            var settings = {
                'charger_enabled': self.charger_enabled == 1? true : false,
                'float_voltage': self.float_voltage,
                'absorption_voltage': self.absorption_voltage,
                'max_charging_current': self.max_charging_current,
                'cv_charging_time': self.cv_charging_time
            }
            tasmota.set_power(self.charger_enabled_idx, self.charger_enabled)
            mqtt.publish(self.mac_addr + '/PC1800', json.dump(settings))
        end
        if self.debug print(string.format('PC1800:Received %s   Bytes: %s',str(msg), bts.tostring(120))) end
        self.settings_counter += 1

        if self.settings_counter >= 10
            self.settings_counter = 0

            while self.message_queue.size() > 0
                self.ser.write(self.message_queue.pop(0))
                self.ser.flush()
                if self.debug print('sending queued message') end
                tasmota.delay(300)
                self.ser.read()
            end

            self.request_settings()
        else

            self.request_state()
        end
    end
    def web_sensor()
        if !self.state_received return nil end
        var msg = string.format(
                 "{s}PC1800 PV voltage{m}%.1f V{e}"..
                 "{s}PC1800 Battery voltage{m}%.1f V{e}"..
                 "{s}PC1800 Charging current{m}%.1f A{e}"..
                 "{s}PC1800 Charging power{m}%d W{e}"..
                 "{s}PC1800 Radiator temperature  {m}%d°C{e}"..
                 "{s}PC1800 Charging stage{m}%s{e}"..
                 "{s}PC1800 MPPT state{m}%s{e}"..
                 "{s}PC1800 PV relay{m}%s{e}"..
                 "{s}PC1800 Battery relay{m}%s{e}"..
                 "{s}PC1800 Accumulated energy{m}%.1f kWh{e}", self.pv_voltage, self.battery_voltage, self.charging_current, self.charging_power, self.radiator_temperature, self.charging_stage, self.mppt_state, self.pv_relay, self.battery_relay, self.accumulated_energy)
        tasmota.web_send_decimal(msg)
    end
    
    def json_append()
        if !self.sensors_published 
            self.sensors_published = true
            def publish_sensors()
                var sensor_info = {
                    'command_topic': self.mac_addr + '/PC1800/set',
                    'state_topic': self.mac_addr + '/PC1800',
                    'unique_id': self.mac_addr + '_PC1800_float_voltage',
                    'object_id': self.mac_addr + '_PC1800_float_voltage',
                    'name': self.mac_addr + ' PC1800 float voltage',
                    'min': 48,
                    'max': 64,
                    'step' : 0.1,
                    'unit_of_measurement': 'V',
                    'value_template': '{{ value_json.float_voltage }}',
                    'command_template': '{"float_voltage": {{ value }} }'
                }
                mqtt.publish('homeassistant/number/' + self.mac_addr + '_PC1800_float_voltage/config', json.dump(sensor_info))
             sensor_info = {
                    'command_topic': self.mac_addr + '/PC1800/set',
                    'state_topic': self.mac_addr + '/PC1800',
                    'unique_id': self.mac_addr + '_PC1800_absorption_voltage',
                    'object_id': self.mac_addr + '_PC1800_absorption_voltage',
                    'name': self.mac_addr + ' PC1800 absorption voltage',
                    'min': 48,
                    'max': 64,
                    'step' : 0.1,
                    'unit_of_measurement': 'V',
                    'value_template': '{{ value_json.absorption_voltage }}',
                    'command_template': '{"absorption_voltage": {{ value }} }'
                }
                mqtt.publish('homeassistant/number/' + self.mac_addr + '_PC1800_absorption_voltage/config', json.dump(sensor_info))
             sensor_info = {
                    'command_topic': self.mac_addr + '/PC1800/set',
                    'state_topic': self.mac_addr + '/PC1800',
                    'unique_id': self.mac_addr + '_PC1800_max_charging_current',
                    'object_id': self.mac_addr + '_PC1800_max_charging_current',
                    'name': self.mac_addr + ' PC1800 max charging current',
                    'min': 0.1,
                    'max': 80,
                    'step' : 0.1,
                    'unit_of_measurement': 'A',
                    'value_template': '{{ value_json.max_charging_current }}',
                    'command_template': '{"max_charging_current": {{ value }} }'
                }
                mqtt.publish('homeassistant/number/' + self.mac_addr + '_PC1800_max_charging_current/config', json.dump(sensor_info))
            end
            publish_sensors()
            tasmota.add_cron('* */5 * * * *', publish_sensors)

            def incoming_mqtt(topic, idx, data)
                var incoming_mqtt = json.load(data)
                if self.debug print(incoming_mqtt) end

                if incoming_mqtt.contains('float_voltage')
                    var msg = Modbus_message(0x01, 0x06, 10103, 1, [int(incoming_mqtt['float_voltage'] * 10)])
                    self.message_queue.push(msg.serialize())
                    self.settings_counter = 10
                end
                if incoming_mqtt.contains('absorption_voltage')
                    var msg = Modbus_message(0x01, 0x06, 10104, 1, [int(incoming_mqtt['absorption_voltage'] * 10)])
                    self.message_queue.push(msg.serialize())
                    self.settings_counter = 10
                end
                if incoming_mqtt.contains('max_charging_current')
                    var msg = Modbus_message(0x01, 0x06, 10108, 1, [int(incoming_mqtt['max_charging_current'] * 10)])
                    self.message_queue.push(msg.serialize())
                    self.settings_counter = 10
                end
            end
            mqtt.subscribe(self.mac_addr + '/PC1800/set', incoming_mqtt)

        end

        if !self.state_received return nil end

        var msg = string.format(', "PC1800": {"PV": {"Voltage": %.1f, "Relay": "%s"}, "Charging": {"Voltage": %.1f, "Relay": "%s", "Current": %.1f, "Power": "%d", "Stage": "%s"}, "Charger": {"State": "%s"}, "MPPT": {"State": "%s"}, "Accumulated": {"Energy": %.1f}, "Temperature": %d}'
        , self.pv_voltage, self.pv_relay, self.battery_voltage, self.battery_relay, self.charging_current, self.charging_power, self.charging_stage, self.charger_state, self.mppt_state, self.accumulated_energy, self.radiator_temperature)
        tasmota.response_append(msg)
    end

    def set_power_handler(cmd, relay_idx)

        var new_state = tasmota.get_power()[self.charger_enabled_idx]

        if self.charger_enabled != new_state
            var msg = Modbus_message(0x01, 0x06, 10101, 1, [new_state ? 1 : 0])
            self.message_queue.push(msg.serialize())
            self.settings_counter = 10
        end
      end

    def request_state()
        var msg = Modbus_message(0x01, 0x03, 15201, 24)
        self.ser.write(msg.serialize())
        self.ser.flush()
        if self.debug print('PC1800:Requested state     '..str(msg)) end
    end

    def request_settings()
        var msg = Modbus_message(0x01, 0x03, 10101, 26)
        self.ser.write(msg.serialize())
        self.ser.flush()
        if self.debug print('PC1800:Requested settings     '..str(msg)) end
    end
end

return PC1800