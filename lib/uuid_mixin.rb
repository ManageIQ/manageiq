module UuidMixin
  extend ActiveSupport::Concern
  included do
    before_create :set_guid, :on => :create
  end

  private

  def set_guid
    self.guid ||= MiqUUID.new_guid if self.respond_to?(:guid) && self.respond_to?(:guid=)
  end

  def default_name_to_guid
    set_guid
    self.name ||= self.guid if self.respond_to?(:guid) && self.respond_to?(:name) && self.respond_to?(:name=)
  end
end
