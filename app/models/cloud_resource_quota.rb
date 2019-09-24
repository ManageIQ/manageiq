class CloudResourceQuota < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id", :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant

  virtual_column :used, :type => :integer

  # find the currently used value for this quota
  def used
    send("#{name}_quota_used")
  end

  def method_missing(method, *args, &block)
    # return -1 for any undefined _quota_used method
    # UI should interpret -1 as "Unknown"
    method.to_s.end_with?("_quota_used") ? -1 : super
  end
end
