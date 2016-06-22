class CorrectStiTypeOnCloudTenant < ActiveRecord::Migration[5.0]
  class CloudTenant < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  NEW_TYPE = 'ManageIQ::Providers::Openstack::CloudManager::CloudTenant'.freeze

  def up
    CloudTenant.where(:type => nil).update_all(:type => NEW_TYPE)
  end

  def down
    CloudTenant.where(:type => NEW_TYPE).update_all(:type => nil)
  end
end
