class CloudTenantFlavor < ApplicationRecord
  belongs_to :cloud_tenant
  belongs_to :flavor
end
