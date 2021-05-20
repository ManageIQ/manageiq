module BelongsToParentManagerMixin
  extend ActiveSupport::Concern

  included do
    belongs_to :parent_manager, :foreign_key => :parent_ems_id, :class_name => "ManageIQ::Providers::BaseManager", :autosave => true

    delegate :queue_name_for_ems_refresh, :to => :parent_manager
  end
end
