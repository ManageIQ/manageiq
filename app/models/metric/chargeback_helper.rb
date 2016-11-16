module Metric::ChargebackHelper
  TAG_MANAGED_PREFIX = "/tag/managed/".freeze

  def hash_features_affecting_rate
    tags = tag_names.split('|').reject { |n| n.starts_with?('folder_path_') }.sort.join('|')
    keys = [tags] + resource_parents.map(&:id)
    keys += [resource.container_image, timestamp] if resource_type == Container.name
    keys.join('_')
  end

  def tag_prefix
    klass_prefix = case resource_type
                   when Container.name        then 'container_image'
                   when VmOrTemplate.name     then 'vm'
                   when ContainerProject.name then 'container_project'
                   end

    klass_prefix + TAG_MANAGED_PREFIX
  end

  def tag_list_reconstruct
    tag_list = tag_names

    if resource_type == Container.name
      state = resource.vim_performance_state_for_ts(timestamp.to_s)
      tag_list += state.image_tag_names if state.present?
    end
    
    tag_list.split("|").map { |tag| "#{tag_prefix}#{tag}" }
  end

  def resource_parents
    [parent_host || resource.try(:host),
     parent_ems_cluster || resource.try(:ems_cluster),
     parent_storage || resource.try(:storage),
     parent_ems || resource.try(:ext_management_system),
     resource.try(:tenant)
    ].compact
  end

  def parents_determining_rate
    case resource_type
    when VmOrTemplate.name
      (resource_parents + [MiqEnterprise.my_enterprise]).compact
    when ContainerProject.name
      [parent_ems].compact
    when Container.name
      []
    end
  end
end
