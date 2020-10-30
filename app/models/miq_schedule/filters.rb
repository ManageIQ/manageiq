module MiqSchedule::Filters
  extend ActiveSupport::Concern

  module Storage
    module Base
      def self.expression(_value, _other_value = nil, _resource_type = nil)
        {"IS NOT NULL" => {"field" => "Storage-name"}}
      end
    end

    module ExtManagementSystem
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"CONTAINS" => {"field" => "Storage.ext_management_systems-name", "value" => value}}
      end
    end

    module Host
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"CONTAINS" => {"field" => "Storage.hosts-name", "value" => value}}
      end
    end

    module Storage
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "Storage-name", "value" => value}}
      end
    end
  end

  module Host
    module Base
      def self.expression(_value, _other_value = nil, _resource_type = nil)
        {"IS NOT NULL" => {"field" => "Host-name"}}
      end
    end

    module EmsCluster
      def self.expression(value, other_value, _resource_type = nil)
        {"AND" => [
          {"=" => {"field" => "Host-v_owning_cluster", "value" => value}},
          {"=" => {"field" => "Host-v_owning_datacenter", "value" => other_value}}
        ]}
      end
    end

    module ExtManagementSystem
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "Host.ext_management_system-name", "value" => value}}
      end
    end

    module Host
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "Host-name", "value" => value}}
      end
    end
  end

  module ContainerImage
    module Base
      def self.expression(_value, _other_value = nil, _resource_type = nil)
        {"IS NOT NULL" => {"field" => "ContainerImage-name"}}
      end
    end

    module ExtManagementSystem
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "ContainerImage.ext_management_system-name", "value" => value}}
      end
    end

    module ContainerImage
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "ContainerImage-name", "value" => value}}
      end
    end
  end

  module ContainerImageCheckCompliance
    include ContainerImage
  end

  module EmsCluster
    module Base
      def self.expression(_value, _other_value = nil, _resource_type = nil)
        {"IS NOT NULL" => {"field" => "EmsCluster-name"}}
      end
    end

    module EmsCluster
      def self.expression(value, other_value, _resource_type = nil)
        {"AND" => [
          {"=" => {"field" => "EmsCluster-name", "value" => value}},
          {"=" => {"field" => "EmsCluster-v_parent_datacenter", "value" => other_value}}
        ]}
      end
    end

    module ExtManagementSystem
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "EmsCluster.ext_management_system-name", "value" => value}}
      end
    end
  end

  module CheckCompliance
    module Base
      def self.expression(_value, _other_value = nil, resource_type = nil)
        {"IS NOT NULL" => {"field" => "#{resource_type}-name"}}
      end
    end

    # review
    module EmsCluster
      def self.expression(value, other_value, resource_type)
        {"AND" => [
          {"=" => {"field" => "#{resource_type}-v_owning_cluster", "value" => value}},
          {"=" => {"field" => "#{resource_type}-v_owning_datacenter", "value" => other_value}}
        ]}
      end
    end

    module ExtManagementSystem
      def self.expression(value, _other_value = nil, resource_type)
        {"=" => {"field" => "#{resource_type}.ext_management_system-name", "value" => value}}
      end
    end

    module Host
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "Host-name", "value" => value}}
      end
    end

    module Vm
      def self.expression(value, _other_value = nil, _resource_type = nil)
        {"=" => {"field" => "Vm-name", "value" => value}}
      end
    end
  end

  module Vm
    module Base
      def self.expression(_value, _other_value, resource_type = nil)
        {"IS NOT NULL" => {"field" => "#{resource_type}-name"}}
      end
    end

    module EmsCluster
      def self.expression(value, other_value, resource_type = nil)
        {"AND" => [
          {"=" => {"field" => "#{resource_type}-v_owning_cluster", "value" => value}},
          {"=" => {"field" => "#{resource_type}-v_owning_datacenter", "value" => other_value}}
        ]}
      end
    end

    module ExtManagementSystem
      def self.expression(value, _other_value = nil, resource_type)
        {"=" => {"field" => "#{resource_type}.ext_management_system-name", "value" => value}}
      end
    end

    module Host
      def self.expression(value, _other_value = nil, resource_type = nil)
        {"=" => {"field" => "#{resource_type}.host-name", "value" => value}}
      end
    end

    module MiqTemplate
      def self.expression(value, _other_value = nil, resource_type = nil)
        {"=" => {"field" => "#{resource_type}-name", "value" => value}}
      end
    end
  end

  module MiqTemplate
    include Vm
  end

  module ContainerImage
    include Vm
  end

  def build_hash_filter_expression(value, other_value = nil, filter_type = "Base")
    namespace = "#{self.class}::#{resource_type_module_name}::#{filter_type}"
    namespace = namespace.safe_constantize
    raise BadRequestError, "Unable to determine type of schedule: #{resource_type_module_name}::#{filter_type} in unrecognized." unless namespace

    namespace.expression(value, other_value, resource_type)
  end

  def build_filter_expression_from(value, other_value = nil, filter_type = "Base")
    expression = build_hash_filter_expression(value, other_value, filter_type)
    schedule.filter = MiqExpression.new(expression)
  end

  def resource_type_module_name
    check_compliance? ? "CheckCompliance" : resource_type
  end

  def check_compliance?
    sched_action&.dig(:method) == "check_compliance"
  end
end
