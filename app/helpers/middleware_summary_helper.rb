module MiddlewareSummaryHelper
  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_middleware_servers
    textual_link(@record.middleware_servers)
  end

  def textual_middleware_server
    textual_link(@record.middleware_server)
  end

  def textual_middleware_deployments
    textual_link(@record.middleware_deployments)
  end
end
