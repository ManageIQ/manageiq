class ReportType < ApplicationRecord
  belongs_to :resource, :polymorphic => true
end
