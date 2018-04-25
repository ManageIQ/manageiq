class ContainerQuotaItem < ApplicationRecord
  # This model is unusual in using archiving not only to record deletions but also changes in quota_desired, quota_enforced, quota_observed.
  # Instead of updating in-place, we archive the old record and create a new one.
  include ArchivedMixin
  include_concern 'Purging'

  belongs_to :container_quota
  has_many :container_quota_scopes, :through => :container_quota

  virtual_column :quota_desired_display,  :type => :string
  virtual_column :quota_enforced_display, :type => :string
  virtual_column :quota_observed_display, :type => :string

  def disconnect_inv
    return if archived?
    _log.info("Archiving Container Quota id [#{container_quota_id}] Item [#{resource}]")
    # This allows looking only at ContainerQuotaItem created_at..deleted_on
    # without also checking parent ContaineQuota is active.
    self.deleted_on = Time.now.utc
    save
  end

  def quota_desired_display
    quota_display(quota_desired)
  end

  def quota_enforced_display
    quota_display(quota_enforced)
  end

  def quota_observed_display
    quota_display(quota_observed)
  end

  private

  def quota_display(quota)
    (quota % 1).zero? ? quota.to_i.to_s : quota.to_s
  end
end
