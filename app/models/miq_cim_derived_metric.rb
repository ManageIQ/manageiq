class MiqCimDerivedMetric < ApplicationRecord
  belongs_to    :miq_storage_metric

  # acts_as_list was blindly upgraded from "~>0.1.4" to "~>0.7.2" to fix
  # a rails 4.x issue.  Keep this in mind when we try using acts_as_list.
  acts_as_list  :scope => :miq_storage_metric
end
