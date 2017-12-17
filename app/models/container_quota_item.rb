class ContainerQuotaItem < ApplicationRecord
  belongs_to :container_quota

  virtual_column :quota_desired_display,  :type => :string
  virtual_column :quota_enforced_display, :type => :string
  virtual_column :quota_observed_display, :type => :string

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
