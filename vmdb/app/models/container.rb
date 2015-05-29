class Container < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  belongs_to :container_group
end
