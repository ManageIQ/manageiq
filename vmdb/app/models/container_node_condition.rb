class ContainerNodeCondition < ActiveRecord::Base
  include ReportableMixin
  belongs_to :container_node
end
