class ConditionSet < ActiveRecord::Base
  acts_as_miq_set

  default_scope { where conditions_for_my_region_default_scope }
end
