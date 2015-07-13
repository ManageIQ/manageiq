module MiqAeServiceRetirementMixin
  extend ActiveSupport::Concern
  included do
    expose :retire_now
    expose :start_retirement
    expose :finish_retirement
    expose :retiring?
    expose :error_retiring?
    expose :retired?
  end

  def retirement_state=(state)
    ar_method { @object.update_attributes(:retirement_state => state) }
  end

  def retires_on=(date)
    _log.info "Setting Retirement Date on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{date.inspect}"
    ar_method { @object.update_attributes(:retires_on => date) }
  end

  def retirement_warn=(days)
    _log.info "Setting Retirement Warning on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{days.inspect}"
    ar_method { @object.update_attributes(:retirement_warn => days) }
  end
end
