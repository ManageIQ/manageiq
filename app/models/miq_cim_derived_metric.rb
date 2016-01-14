class MiqCimDerivedMetric < ApplicationRecord
  belongs_to    :miq_storage_metric
  acts_as_list  :scope => :miq_storage_metric
end
