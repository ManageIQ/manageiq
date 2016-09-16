module MiqProvision::Retirement
  def set_retirement(vm)
    retire_date = nil

    retirement = get_option(:retirement).to_i
    retire_date = (Time.now.utc + retirement) unless retirement == 0

    retirement_time = get_option(:retirement_time)
    retire_date = retirement_time unless retirement_time.nil?

    unless retire_date.nil?
      _log.info("#{vm.class.base_model.name}:[#{vm.name}] set to retire on [#{retire_date}]")
      vm.retires_on = retire_date
      vm.retirement_warn = get_option(:retirement_warn).to_i / 1.day.to_i
    end
  end
end
