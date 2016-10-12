module Metric::ChargebackHelper
  def hash_features_affecting_rate
    tags = tag_names.split('|').reject { |n| n.starts_with?('folder_path_') }.sort.join('|')
    keys = [tags, parent_host_id, parent_ems_cluster_id, parent_storage_id, parent_ems_id]
    keys += [resource.container_image, timestamp] if resource_type == Container.name
    tenant_resource = resource.try(:tenant)
    keys.push(tenant_resource.id) unless tenant_resource.nil?
    keys.join('_')
  end
end
