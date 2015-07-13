class TenantResource < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :resource, :polymorphic => true
end
