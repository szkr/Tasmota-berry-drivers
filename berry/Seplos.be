import string

class Seplos
    var ser, address
    var pack_voltage, pack_current, remaining_ah, full_ah, remaining_percent, rated_ah, cycles, heath_percent, port_voltage
    var env_temperature, pcb_temperature
    var cell_voltages
    var cell_temperatures
    var expected_response
    var debug

    def init(ser, address, debug)
        print("Seplos BMS: Init")
        self.ser = ser
        self.address = address
        self.debug = debug != nil ? debug : false

        if !self.ser
            print("Seplos BMS: Couldn't get serial")
        end
        if self.address == nil
            self.address = 0
        end
    end

    def every_second()
        if !self.ser return nil end
        var msg = self.ser.read()
        if self.validate_message(msg)
            var msg_hex = bytes(msg[1..-6].asstring())
            var strbts=''
            for i:0..msg_hex.size()-1
                strbts+=string.format('%02X ', msg_hex[i])
            end
            if self.debug print(strbts) end
            if '42' == self.expected_response
                self.decode_42(msg_hex)
                self.send_command('44')
                return
            end
            if '44' == self.expected_response
                self.decode_44(msg_hex)
                self.send_command('42')
                return
            end
        end
        self.send_command('42')
    end

    def decode_44(msg_hex)
    end

    def decode_42(msg_hex)
        var num_of_cells = msg_hex.get(8, -1)
        if self.cell_voltages == nil
            self.cell_voltages = []
            self.cell_voltages.resize(num_of_cells)
        end
        var current_pos = 9
        for j:0..num_of_cells-1
            var v = msg_hex.get(current_pos, -2)/1000.0
            self.cell_voltages[j] = v
            current_pos += 2
        end
        var num_of_temperatures = msg_hex.get(current_pos, -1)
        current_pos += 1
        if self.cell_temperatures == nil
            self.cell_temperatures = []
            self.cell_temperatures.resize(num_of_temperatures)
        end
        for j:0..num_of_temperatures - 1
            var t = (msg_hex.get(current_pos, -2) - 2731) / 10.0
            self.cell_temperatures[j] = t
            current_pos += 2
        end
        self.pack_current = msg_hex.geti(current_pos, -2)/10.0
        current_pos += 2
        self.pack_voltage = msg_hex.get(current_pos, -2)/1000.0
        current_pos += 7
        # self.remaining_ah = msg_hex.get(current_pos, -2)/100.0
        # current_pos += 3
        # self.full_ah = msg_hex.get(current_pos, -2)/100.0
        # current_pos += 2
        # self.remaining_percent = msg_hex.get(current_pos, -2)/100.0
        # current_pos += 2
        # self.rated_ah = msg_hex.get(current_pos, -2)/100.0
        # current_pos += 2
        self.cycles = msg_hex.get(current_pos, -2)
        current_pos += 2
        self.remaining_ah = msg_hex.get(current_pos, -3)/1000.0
        current_pos += 3
        # self.heath_percent = msg_hex.get(current_pos, -2)/100.0
        # current_pos += 2
        # self.port_voltage = msg_hex.get(current_pos, -2)/100.0
        # current_pos += 2
    end

    def web_sensor()
        if !self.ser return nil end
        import string
        var msg = string.format(
                 "{s}Seplos BMS Pack voltage{m}%2.3f V{e}"..
                 "{s}Seplos BMS Pack current{m}%2.2f A{e}"..
                 "{s}Seplos BMS remaining capacity{m}%.3f Ah{e}"..
                 "{s}Seplos BMS full capacity{m}%.2f Ah{e}"..
                 "{s}Seplos BMS remaining percent{m}%.2f %%{e}"..
                 "{s}Seplos BMS rated capacity{m}%.2f Ah{e}"..
                 "{s}Seplos BMS cycles{m}%d{e}"..
                 "{s}Seplos BMS health{m}%.2f %%{e}"..
                 "{s}Seplos BMS port voltage{m}%2.2f V{e}"
                 , self.pack_voltage, self.pack_current, self.remaining_ah, self.full_ah, self.remaining_percent, self.rated_ah, self.cycles, self.heath_percent, self.port_voltage)
        tasmota.web_send_decimal(msg)
    end
    
    def json_append()
        if !self.ser return nil end
        var cell_voltages_str = ''
        var cell_temperatures_str = ''
        if self.cell_voltages != nil
            var lowest_cell_voltage = self.cell_voltages[0]
            var highest_cell_voltage = self.cell_voltages[0]
                cell_voltages_str = ''
                for i:0..self.cell_voltages.size()-1
                    if self.cell_voltages[i] < lowest_cell_voltage
                        lowest_cell_voltage = self.cell_voltages[i]
                    end
                    if self.cell_voltages[i] > highest_cell_voltage
                        highest_cell_voltage = self.cell_voltages[i]
                    end
                    cell_voltages_str += string.format(',"Cell %02d":{"Voltage":%.3f}', i+1, self.cell_voltages[i])
                end
                cell_voltages_str += string.format(',"Cell delta":{"Voltage":%.3f}', highest_cell_voltage - lowest_cell_voltage)
        end
        if self.cell_temperatures != nil
            cell_temperatures_str = ''
            for i:0..self.cell_temperatures.size()-1
                if i != 0 cell_temperatures_str += ',' end
                cell_temperatures_str += string.format('"Sensor %02d":%.1f', i+1, self.cell_temperatures[i])
            end
        end
        var msg = string.format(',"BMS":{"Pack": {"Voltage": %.3f, "Current":%.2f},"Battery":%.3f%s, "Temperature":{%s}}', self.pack_voltage, self.pack_current, self.remaining_ah/120*100, cell_voltages_str, cell_temperatures_str)
        tasmota.response_append(msg)
    end

    def send_command(command_ascii)
        var address_ascii=bytes().fromstring(string.format('%02d', self.address))
        var msg=bytes()
        msg.add(0x7E) # starting character
        msg += bytes().fromstring('20') # protocol version
        msg += address_ascii # bms address
        msg += bytes().fromstring('46') # device code
        msg += bytes().fromstring(command_ascii) # command code
        msg += bytes().fromstring(self.get_length_ascii(size(address_ascii))) # length with it's checksum
        msg += address_ascii # INFO section which is just bms address when master->slave
        msg += bytes().fromstring(self.get_checksum_ascii(msg[1..])) # length with checksum
        msg.add(0x0D) # ending character

        
        var msg_hex = bytes(msg[1..-2].asstring())
        var strbts=''
        for i:0..msg_hex.size()-1
            strbts+=string.format('%02X ', msg_hex[i])
        end
        self.ser.write(msg)
        self.ser.flush()
        self.expected_response = command_ascii
        if self.debug print(strbts) end
    end

    def get_length_ascii(info_length)
        var length_checksum=((info_length>>8)%16)+((info_length>>4)%16)+(info_length%16)
        length_checksum = length_checksum % 16
        length_checksum = (~length_checksum + 1) & 0xF
        return string.format('%X%03X', length_checksum, info_length)
    end
    
    def get_checksum_ascii(message_bytes) # expected message without start char, end char and checksum
        var checksum = 0
        for i:0..message_bytes.size()-1
            checksum+=message_bytes[i]
        end
        checksum = checksum % 65536
        checksum = (~checksum + 1) & 0xFFFF
        return string.format('%04X', checksum)
    end


    def validate_message(msg_ascii)
        if !msg_ascii || size(msg_ascii) < 18
            print("Seplos BMS: validate message: too short/empty")
            return false
        end
        if msg_ascii[0] != 0x7E || msg_ascii[msg_ascii.size()-1] != 0x0D
            print("Seplos BMS: validate message: wrong start/end character")
            return false
        end
        if bytes(msg_ascii[3..4].asstring())[0] != self.address
            print("Seplos BMS: validate message: wrong address")
            return false
        end
        if bytes(msg_ascii[9..13].asstring()).tohex() != self.get_length_ascii(msg_ascii.size() - 18)
            print("Seplos BMS: validate message: length field doesn't match actual message length")
            return false
        end
        if bytes(msg_ascii[-5..-2].asstring()).tohex() != self.get_checksum_ascii(msg_ascii[1..-6])
            print("Seplos BMS: validate message: wrong checksum")
            return false
        end
        return true
    end
end

return Seplos