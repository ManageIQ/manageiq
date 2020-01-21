class ServiceTemplateTenant < ApplicationRecord
  belongs_to :service_template
  belongs_to :tenant
end
