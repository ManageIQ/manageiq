module UuidMixin
  extend ActiveSupport::Concern
  included do
    default_value_for(:guid) { SecureRandom.uuid }
    validates :guid,  :uniqueness_when_changed => true, :presence => true
  end

  def dup
    super.tap { |obj| obj.guid = SecureRandom.uuid }
  end

  private

  def default_name_to_guid
    self.name ||= self.guid if self.respond_to?(:guid) && self.respond_to?(:name) && self.respond_to?(:name=)
  end
end
