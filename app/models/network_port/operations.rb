module NetworkPort::Operations
  extend ActiveSupport::Concern

  def update_network_port(options = {})
    raw_update_network_port(options)
  end

  def raw_update_network_port(_options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def delete_network_port
    raw_delete_network_port
  end

  def raw_delete_network_port
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
