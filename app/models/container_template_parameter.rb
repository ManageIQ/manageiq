class ContainerTemplateParameter < ApplicationRecord
  include CustomAttributeMixin
  belongs_to :container_template

  def instantiation_attributes
    attributes.slice("name", "value", "generate", "from", "required")
  end
end
