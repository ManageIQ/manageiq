class SecurityContext < ApplicationRecord
  belongs_to :resource, :polymorphic => true
end
