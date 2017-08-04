module CloudNetwork::Operations
  extend ActiveSupport::Concern

  def update_cloud_network(options={})
    raw_update_cloud_network(options)
  end

  def raw_update_cloud_network(_options={})
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def delete_cloud_network
    raw_delete_cloud_network
  end

  def raw_delete_cloud_network
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
