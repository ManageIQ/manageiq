class AutomateWorkspace < ApplicationRecord
  include UuidMixin
  belongs_to :user
  belongs_to :tenant
  validates :tenant, :presence => true
  validates :user, :presence => true

  def href_slug
    Api::Utils.build_href_slug(self.class, guid)
  end

  def merge_output!(hash)
    if hash['objects'].nil? || hash['state_vars'].nil?
      raise ArgumentError, "No objects or state_vars specified for edit"
    end

    self[:output] = (output || {}).deep_merge(hash)
    save!
    self
  end
end
