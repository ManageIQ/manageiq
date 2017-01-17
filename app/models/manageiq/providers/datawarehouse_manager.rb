module ManageIQ::Providers
  class DatawarehouseManager < BaseManager
    has_many :datawarehouse_nodes, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cluster_attributes, -> { where(:section => "cluster_attributes") }, :class_name => CustomAttribute, :as => :resource, :dependent => :destroy

    class << model_name
      def route_key
        "ems_datawarehouse"
      end

      def singular_route_key
        "ems_datawarehouse"
      end
    end
  end
end
