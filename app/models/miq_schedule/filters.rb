module MiqSchedule::Filters
  extend ActiveSupport::Concern

  def build_hash_filter_expression(value, other_value = nil, filter_type = "Base")
    check_compliance = sched_action&.dig(:method) == "check_compliance"
    filter_resource_type = if check_compliance
                             if resource_type == "ContainerImage"
                               "ContainerImageCheckCompliance"
                             else
                               "CheckCompliance"
                             end
                           else
                             resource_type
                           end

    case filter_resource_type
    when "Storage"
      case filter_type
      when "ExtManagementSystem" then {"CONTAINS" => {"field" => "Storage.ext_management_systems-name", "value" => value}}
      when "Host"                then {"CONTAINS" => {"field" => "Storage.hosts-name", "value" => value}}
      when "Storage"             then {"=" => {"field" => "Storage-name", "value" => value}}
      else {"IS NOT NULL" => {"field" => "Storage-name"}}
      end
    when "Host"
      case filter_type
      when "EmsCluster"
        if value.present?
          {"AND" => [
            {"=" => {"field" => "Host-v_owning_cluster", "value" => value}},
            {"=" => {"field" => "Host-v_owning_datacenter", "value" => other_value}}
          ]}
        end
      when "ExtManagementSystem" then {"=" => {"field" => "Host.ext_management_system-name", "value" => value}}
      when "Host"                then {"=" => {"field" => "Host-name", "value" => value}}
      else {"IS NOT NULL" => {"field" => "Host-name"}}
      end
    when "ContainerImage", "ContainerImageCheckCompliance"
      case filter_type
      when "ExtManagementSystem" then {"=" => {"field" => "ContainerImage.ext_management_system-name", "value" => value}}
      when "ContainerImage"      then {"=" => {"field" => "ContainerImage-name", "value" => value}}
      else {"IS NOT NULL" => {"field" => "ContainerImage-name"}}
      end
    when "EmsCluster"
      case filter_type
      when "EmsCluster"
        if value.present?
          {"AND" => [
            {"=" => {"field" => "EmsCluster-name", "value" => value}},
            {"=" => {"field" => "EmsCluster-v_parent_datacenter", "value" => other_value}}
          ]}
        end
      when "ExtManagementSystem" then {"=" => {"field" => "EmsCluster.ext_management_system-name", "value" => value}}
      else {"IS NOT NULL" => {"field" => "EmsCluster-name"}}
      end
    when "CheckCompliance"
      case filter_type
      when "EmsCluster"
        if value.present?
          {"AND" => [
            {"=" => {"field" => "#{resource_type}-v_owning_cluster", "value" => value}},
            {"=" => {"field" => "#{resource_type}-v_owning_datacenter", "value" => other_value}}
          ]}
        end
      when "ExtManagementSystem" then {"=" => {"field" => "#{resource_type}.ext_management_system-name", "value" => value}}
      when "Host" then {"=" => {"field" => "Host-name", "value" => value}}
      when "Vm"   then {"=" => {"field" => "Vm-name", "value" => value}}
      else             {"IS NOT NULL" => {"field" => "#{resource_type}-name"}}
      end
    else
      case filter_type
      when "EmsCluster"
        if value.present?
          {"AND" => [
            {"=" => {"field" => "#{resource_type}-v_owning_cluster", "value" => value}},
            {"=" => {"field" => "#{resource_type}-v_owning_datacenter", "value" => other_value}}
          ]}
        end
      when "ExtManagementSystem" then {"=" => {"field" => "#{resource_type}.ext_management_system-name", "value" => value}}
      when "Host"         then {"=" => {"field" => "#{resource_type}.host-name", "value" => value}}
      when "MiqTemplate", "Vm", "ContainerImage" then {"=" => {"field" => "#{resource_type}-name", "value" => value}}
      else {"IS NOT NULL" => {"field" => "#{resource_type}-name"}}
      end
    end
  end

  def build_filter_expression_from(value, other_value = nil, filter_type = "Base")
    expression = build_hash_filter_expression(value, other_value, filter_type)
    schedule.filter = MiqExpression.new(expression)
  end
end
