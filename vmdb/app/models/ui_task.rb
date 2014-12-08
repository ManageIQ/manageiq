class UiTask < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  validates_presence_of     :area, :typ, :task, :name

  acts_as_miq_set_member
end
