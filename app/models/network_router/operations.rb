module NetworkRouter::Operations
  extend ActiveSupport::Concern

  def delete_network_router
    raw_delete
  end

  def raw_delete
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
