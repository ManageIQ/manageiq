module MiqProvisionTaskConfiguredSystemForeman::OperationsHelper
  def refresh
    EmsRefresh.queue_refresh(source)
  end
end
