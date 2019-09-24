module Metric::ChargebackHelper
  def resource_parents
    [parent_host || resource.try(:host),
     parent_ems_cluster || resource.try(:ems_cluster),
     parent_storage || resource.try(:storage) || resource.try(:cloud_volumes),
     parent_ems || resource.try(:ext_management_system),
     resource.try(:tenant)].flatten.compact
  end

  def parents_determining_rate
    case resource_type
    when VmOrTemplate.name
      (resource_parents + [MiqEnterprise.my_enterprise]).compact
    when ContainerProject.name
      [parent_ems, MiqEnterprise.my_enterprise].compact
    when Container.name
      [parent_ems].compact
    end
  end

  def resource_current_tag_names
    resource ? resource.tags.collect(&:name).map { |x| x.gsub("/managed/", "") } : []
  end

  def resource_tag_names
    tag_names ? tag_names.split("|") : []
  end

  def all_tag_names
    resource_current_tag_names | resource_tag_names
  end
end
