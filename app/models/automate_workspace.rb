class AutomateWorkspace < ApplicationRecord
  include UuidMixin
  belongs_to :user
  belongs_to :tenant
  validates :tenant, :presence => true
  validates :user, :presence => true

  def merge_output!(hash)
    if hash['workspace'].nil? || hash['state_vars'].nil?
      raise ArgumentError, "No workspace or state_vars specified for edit"
    end

    self[:output] = (output || {}).deep_merge(hash)
    save!
    self
  end
end
