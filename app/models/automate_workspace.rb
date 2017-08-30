class AutomateWorkspace < ApplicationRecord
  include UuidMixin
  belongs_to :user
  belongs_to :tenant
  validates :tenant, :presence => true, :message => "is needed to own the workspace"
  validates :user, :presence => true, :message => "is needed to own the workspace"

  def output=(hash)
    if hash['workspace'].blank? && hash['state_var'].blank?
      raise ArgumentError, "No workspace or state_var specified for edit"
    end

    self[:output] = (output || {}).deep_merge(hash)
    save!
    self
  end
end
