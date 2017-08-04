module FloatingIp::Operations
  extend ActiveSupport::Concern

  def update_floating_ip(options = {})
    raw_update_floating_ip(options)
  end

  def raw_update_floating_ip(_options = {})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def delete_floating_ip
    raw_delete_floating_ip
  end

  def raw_delete_floating_ip
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
