import gpio
import string

class JunctekKH
    var ser
    var measurement_ready
    var voltage, current, remaing_ah, temperature, kwh_charged, kwh_discharged, minutes_remaining
    var debug

    def init(ser, debug)
        self.measurement_ready = false
        self.ser = ser
        self.debug = debug != nil ? debug : false
        print("JunctekKH: Init")
        if !self.ser
            print("JunctekKH: Couldn't get serial")
        end
    end

    def every_second()
        if !self.ser return nil end
        self.read_command()
        self.send_command(false, 50)
    end

    def web_sensor()
        if !self.measurement_ready return nil end
        var msg = string.format(
                 "{s}Battery Voltage{m}%2.2f V{e}" ..
                 "{s}Battery Current{m}%2.2f A{e}" ..
                 "{s}Battery Power{m}%4.2f W{e}" ..
                 "{s}Battery Remaining{m}%3.2f %%{e}" ..
                 "{s}Battery Temperature{m}%3.0f C{e}" ..
                 "{s}Battery Energy Charged{m}%.3f kWh{e}" ..
                 "{s}Battery Energy Discharged{m}%.3f kWh{e}", self.voltage, self.current, self.voltage * self.current, self.remaing_ah / 120.0 * 100, self.temperature, self.kwh_charged, self.kwh_discharged)
        tasmota.web_send_decimal(msg)
    end
    
    def json_append()
        if !self.measurement_ready return nil end
        var msg = string.format(",\"Battery\":{\"Voltage\":%2.2f,\"Current\":%3.2f,\"Power\":%4.2f,\"Battery\":%3.2f,\"Temperature\":%3.0f,\"Charged\":{\"Energy\":%.3f},\"Discharged\":{\"Energy\":%.3f}}", self.voltage, self.current, self.voltage * self.current, self.remaing_ah / 120.0 * 100, self.temperature, self.kwh_charged, self.kwh_discharged)
        tasmota.response_append(msg)
    end

    def send_command(write, func_code, args, address)
        if !self.ser return nil end 
        if address == nil address = 1 end

        
        if type(args) != 'int' && !isinstance(args, list)
            args = [1]
        elif type(args) != 'int'
            args = [args]
        end
        var checksum = 0
        for arg : args
            checksum+=arg
        end
        var msg = string.format(':%s%02d=%d,%d,', write?'W':'R', func_code, address, (checksum%255)+1)
        for arg : args
            msg+=string.format('%d,', arg)
        end
        msg+='\r\n'
        self.ser.write(bytes().fromstring(msg))
        self.ser.flush()
        if self.debug
            print('---WRITE')
            print(msg)
            print(bytes().fromstring(msg))
        end
    end

    def read_command()
        if !self.ser return nil end
        var bts=self.ser.read()
        if self.debug
            print('---READ')
            print(bts)
        end
        var s = bts.asstring()
        for msg : string.split(s, ':')
            msg=string.tolower(msg)
            msg=string.tr(msg, ' ', '')
            msg=string.tr(msg, '\r', '')
            msg=string.tr(msg, '\n', '')
            var e=string.split(msg, '=')
            if e.size() == 2
                var read = e[0][0] == 'r'
                var reg = int(e[0][1 ..])
                if reg == 50
                    self.parse_measurements(e[1])
                end
            end
        end
    end

    def parse_measurements(message)
        if self.debug print(message) end
        var values = string.split(message, ',')
        if values.size() != 17 return end
        self.voltage = int(values[2]) / 100.0
        self.current = int(values[3]) / 100.0
        if values[11] == '0' && self.current > 0
            self.current = self.current * -1
        end
        self.remaing_ah = int(values[4]) / 1000.0
        self.kwh_discharged = int(values[5]) / 100000.0
        self.kwh_charged = int(values[6]) / 100000.0
        self.temperature = int(values[8]) - 100
        self.minutes_remaining = int(values[12])
        self.measurement_ready = true
        if self.debug
            print(string.format('%2.2fV  %2.2fA  %4.2fW  remaining: %3.2fAh  %dC    Charged:%4.3f  Discharged:%4.3f', self.voltage, self.current, self.voltage * self.current, self.remaing_ah, self.temperature, self.kwh_charged, self.kwh_discharged))
        end
    end
end

return JunctekKH