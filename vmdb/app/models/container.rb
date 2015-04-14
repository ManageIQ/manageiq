class Container < ActiveRecord::Base
  include ReportableMixin
  belongs_to :container_group
end
