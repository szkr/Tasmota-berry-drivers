import string

class Modbus_message
    var address
    var command
    var start_register
    var amount
    var register_values
    var transform_error
    
    def init(address, command, start_register, amount, register_values)
        self.address = address
        self.command = command
        self.start_register = start_register
        self.amount = amount
        self.register_values = register_values
    end

    def from_bytes(bts)
        if bts == nil || bts.size() < 5
            self.transform_error = 'Message too short/empty'
            return false
        end

        if self.get_crc(bts[0..-3]) != bts.get(bts.size()-2, -2)
            self.transform_error = 'Wrong CRC'
            return false
        end
        self.address = bts[0]
        self.command = bts[1]
        if self.command == 0x03
            self.amount = bts[2] / 2
            if bts.size() != self.amount*2+5
                self.transform_error = 'Wrong message length'
                return false
            end
            self.register_values = []
            for i:0..self.amount
                self.register_values.push(bts.get(i*2+3, -2))
            end
        end

        return true 
    end

    def serialize()
        var msg=bytes()
        msg.add(self.address)
        msg.add(self.command)
        msg.add(self.start_register, -2)
        if self.command == 0x03
            msg.add(self.amount, -2)
        end
        if self.command == 0x06
            if size(self.register_values) == 0
                self.transform_error = 'Register value missing'
                return nil
            end
            msg.add(self.register_values[0], -2)
        end
        msg.add(self.get_crc(msg), -2)
        return msg
    end

    def tostring()
        if self.transform_error != nil
            return self.transform_error
        end
        var ret=string.format('Address: 0x%02X, Command: 0x%02X, Start register: %4d, Amount: %2d', self.address, self.command, self.start_register, self.amount)
        if(self.register_values)
            ret+=', Register values:['
            for i:0..self.register_values.size() - 2
                ret+=string.format('%d%s', self.register_values[i], i != self.register_values.size() - 2 ? ', ' : '')
            end
            ret+=']'
        end
        return ret
    end
    
    def get_crc(bts)
        var crc = 0xFFFF
        for n:0..bts.size()-1
            crc ^= bts[n]
            for i:0..7
                if crc & 1
                    crc >>= 1
                    crc ^= 0xA001
                else
                    crc >>= 1
                end
            end
        end
        return ((crc >> 8) | (crc << 8)) & 0xFFFF
    end

    def get_register(idx, signed)
        if signed
            var b = bytes();
            b.add(self.register_values[idx], -2)
            return b.geti(0, -2)
        end
        return self.register_values[idx]
    end
end

return Modbus_message