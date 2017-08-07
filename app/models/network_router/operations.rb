module NetworkRouter::Operations
  extend ActiveSupport::Concern

  def update_network_router(options = {})
    raw_update_network_router(options)
  end

  def raw_update_network_router(_options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
