class ScanResult < ApplicationRecord
  belongs_to :resource, :polymorphic => true
end
