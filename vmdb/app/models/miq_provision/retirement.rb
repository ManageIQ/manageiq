module MiqProvision::Retirement
  def set_retirement(vm)
    log_header = "MIQ(#{self.class.name}.set_retirement)"

    retire_date = nil
    retirement = get_option(:retirement).to_i
    retire_date = (Time.now.utc + retirement).to_date unless retirement == 0
    retirement_time = get_option(:retirement_time)
    retire_date = retirement_time.to_date unless retirement_time.nil?
    unless retire_date.nil?
      $log.info("#{log_header} #{vm.class.base_model.name}:[#{vm.name}] set to retire on [#{retire_date}]")
      vm.retires_on = retire_date
      vm.retirement_warn = get_option(:retirement_warn).to_i / 1.day.to_i
    end
  end
end
