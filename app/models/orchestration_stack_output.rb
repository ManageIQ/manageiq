class OrchestrationStackOutput < ActiveRecord::Base
  include ReportableMixin

  belongs_to :stack, :class_name => "OrchestrationStack"
  include ReportableMixin

  alias_attribute :name, :key
end
