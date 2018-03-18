class ContainerQuota < ApplicationRecord
  # For this model and children, we want to record full changes history.
  #
  # - The ContainerQuota itself doesn't have anything that changes
  #   (except resource_version whose history is not interesting).
  #   So we do standard archiving on deletion here.
  #
  # - Scopes are immutable once ContainerQuota is created, so don't need archiving.
  #
  # - ContainerQuotaItems can be added/deleted/changed, and we use archiving to
  #   record changes too!
  include ArchivedMixin
  include_concern 'Purging'

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project

  has_many :container_quota_scopes, :dependent => :destroy
  has_many :container_quota_items, -> { active }
  has_many :all_container_quota_items, :class_name => "ContainerQuotaItem", :dependent => :destroy

  def disconnect_inv
    return if archived?
    _log.info("Archiving Container Quota [#{name}] id [#{id}]")
    # This allows looking only at ContainerQuotaItem created_at..deleted_on
    # without also checking parent ContaineQuota is active.
    container_quota_items.each(&:disconnect_inv)
    self.deleted_on = Time.now.utc
    save
  end
end
