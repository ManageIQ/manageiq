class ContainerTemplateParameter < ApplicationRecord
  include CustomAttributeMixin
  belongs_to :container_template
end
