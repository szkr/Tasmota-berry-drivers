import gpio
import string

class RelayPowersave
  var relay_idx, gpio, state, inverted, pwm_value, timer_id
  var pwm_start, pwm_end, closed
  def init(gpio_relay, inverted, save_duty)
    self.pwm_value = save_duty == nil ? 250 : save_duty
    self.inverted = inverted
    self.gpio = gpio_relay
    self.relay_idx = tasmota.global.devices_present
    self.closed = false;
    tasmota.global.devices_present += 1
    self.timer_id = 'PSR' + str(self.relay_idx)
    gpio.pin_mode(self.gpio, gpio.OUTPUT)
    tasmota.add_fast_loop(/-> self.fast_loop())
    self.set_power_handler()
  end

  def set_power_handler()
    var new_state = tasmota.get_power()[self.relay_idx]
    if self.state != new_state
      tasmota.remove_timer(self.timer_id)
      self.state = new_state
      if self.state
        gpio.set_pwm(self.gpio, self.inverted? 0 : 1023)
        self.pwm_start = tasmota.millis(1000)
        self.pwm_end = tasmota.millis(2000)
      else
        self.pwm_start = -1
        if self.closed
          gpio.set_pwm(self.gpio, self.inverted? 0 : 1023)
          tasmota.delay(50)
        end
        gpio.set_pwm(self.gpio, self.inverted ? 1023 : 0)
      end
    end
  end
  def fast_loop()
    if self.pwm_start == -1 return end
    if !tasmota.time_reached(self.pwm_start)
      gpio.set_pwm(self.gpio, self.inverted ? 0 : 1023)
      return
    end
    var slope = (self.pwm_value - 1023) / 1000.0
    var value = int(1023 + slope * (tasmota.millis() - self.pwm_start))
    gpio.set_pwm(self.gpio, self.inverted ? (1023 - value) : value)

    if(tasmota.time_reached(self.pwm_end))
      gpio.set_pwm(self.gpio, self.inverted ? (1023 - self.pwm_value) : self.pwm_value)
      self.pwm_start = -1
    end
  end
end

return RelayPowersave