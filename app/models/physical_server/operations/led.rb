module PhysicalServer::Operations::Led
  def blink_loc_led
    change_state(:blink_loc_led)
  end

  def turn_on_loc_led
    change_state(:turn_on_loc_led)
  end

  def turn_off_loc_led
    change_state(:turn_off_loc_led)
  end
end
