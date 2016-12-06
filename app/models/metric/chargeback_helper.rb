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

  def tag_list_with_prefix
    if resource.kind_of?(Container)
      state = resource.vim_performance_state_for_ts(timestamp.to_s)
      image_tag_name = "#{state.image_tag_names}|" if state
      labels = resource.try(:container_image).try(:docker_labels).try(:collect) { |l| "container_image/label/managed/#{l.name}/#{l.value}" }
    end

    "#{image_tag_name}#{tag_names}".split("|").reject(&:empty?).map { |x| "#{tag_prefix}#{x}" } + (labels || [])
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
      [parent_ems]
    end
  end
end
