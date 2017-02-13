class TenantFlavor < ApplicationRecord
  belongs_to :tenant
  belongs_to :flavor
end
