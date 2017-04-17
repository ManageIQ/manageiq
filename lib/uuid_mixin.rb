module UuidMixin
  extend ActiveSupport::Concern
  included do
    before_validation :set_guid, :on => :create if respond_to?(:before_validation)
    before_validation :set_manager_group, :on => :create if respond_to?(:before_validation)
  end

  private

  def set_guid
    self.guid ||= MiqUUID.new_guid if self.respond_to?(:guid) && self.respond_to?(:guid=)
  end

  def set_manager_group
    self.manager_group ||= MiqUUID.new_guid if self.respond_to?(:manager_group) && self.respond_to?(:manager_group=)
  end

  def default_name_to_guid
    set_guid
    self.name ||= self.guid if self.respond_to?(:guid) && self.respond_to?(:name) && self.respond_to?(:name=)
  end
end
