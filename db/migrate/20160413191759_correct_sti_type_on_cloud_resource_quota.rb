class CorrectStiTypeOnCloudResourceQuota < ActiveRecord::Migration[5.0]
  class CloudResourceQuota < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  NEW_TYPE = 'ManageIQ::Providers::Openstack::CloudManager::CloudResourceQuota'.freeze
  OLD_TYPE = 'CloudResourceQuotaOpenstack'.freeze
  EVEN_OLDER_TYPE = 'OpenstackResourceQuota'.freeze

  def up
    CloudResourceQuota.where(:type => OLD_TYPE).update_all(:type => NEW_TYPE)
    CloudResourceQuota.where(:type => EVEN_OLDER_TYPE).update_all(:type => NEW_TYPE)
  end

  def down
    CloudResourceQuota.where(:type => NEW_TYPE).update_all(:type => OLD_TYPE)
  end
end
