module MiddlewareSummaryHelper
  include TextualMixins::TextualName

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_nativeid
    @record.nativeid
  end

  def textual_group_smart_management
    %i(tags)
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

  def textual_middleware_datasources
    textual_link(@record.middleware_datasources)
  end

  def textual_middleware_domain
    textual_link(@record.middleware_domain)
  end

  def textual_middleware_domains
    textual_link(@record.middleware_domains)
  end

  def textual_middleware_server_group
    textual_link(@record.middleware_server_group)
  end

  def textual_middleware_server_groups
    textual_link(@record.middleware_server_groups)
  end

  def textual_middleware_messagings
    textual_link(@record.middleware_messagings)
  end
end
