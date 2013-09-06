module MiqAeServiceRetirementMixin

  def retirement_state=(state)
    ar_method do
      @object.retirement_state = state
      @object.save
    end
  end

  def retires_on=(date)
    $log.info "MIQ(#{self.class.name}#retires_on=) Setting Retirement Date on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{date.inspect}"
    ar_method do
      @object.retires_on = date
      @object.save
    end
  end

  def retirement_warn=(seconds)
    $log.info "MIQ(#{self.class.name}#retirement_warn=) Setting Retirement Warning on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{seconds.inspect}"
    ar_method do
      @object.retirement_warn = seconds
      @object.save
    end
  end

end