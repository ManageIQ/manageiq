class Container < ActiveRecord::Base
  include ReportableMixin
  # :container_id, :name, :image, :state, :restart_count
  belongs_to :container_group
end
