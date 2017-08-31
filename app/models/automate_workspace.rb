class AutomateWorkspace < ApplicationRecord
  include UuidMixin
  belongs_to :user
  belongs_to :tenant
  validates :tenant, :presence => true
  validates :user, :presence => true

  def merge_output(hash)
    if hash['workspace'].blank? && hash['state_var'].blank?
      raise ArgumentError, "No workspace or state_var specified for edit"
    end

    self[:output] = (output || {}).deep_merge(hash)
    save!
    self
  end
end
