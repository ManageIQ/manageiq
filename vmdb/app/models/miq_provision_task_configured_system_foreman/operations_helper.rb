module MiqProvisionTaskConfiguredSystemForeman::OperationsHelper
  def powered_off?
    !source.with_provider_object(&:powered_on?)
  end

  def refresh
    EmsRefresh.queue_refresh(source)
  end
end
