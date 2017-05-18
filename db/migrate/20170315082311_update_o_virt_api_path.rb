#
# Starting with version 4.0 of oVirt, the support for the /api URL path has been removed, and replaced
# by /ovirt-engine/api, which was introduced in oVirt 3.5. All previous versions of oVirt are already
# out of support. The providers that were created with previous versions of oVirt will have stored in
# the database the old path, and will stop working when migrated to oVirt 4.0. To avoid that issue this
# migration updates all the relevant providers to use the new supported URL path.
#
class UpdateOVirtApiPath < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Endpoint < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time('Upddate oVirt providers API path to /ovirt-engine/api') do
      providers = ExtManagementSystem.where(:type => 'ManageIQ::Providers::Redhat::InfraManager')
      providers.each do |provider|
        Endpoint.where(
          :resource_type => 'ExtManagementSystem',
          :resource_id   => provider.id,
          :role          => 'default',
          :path          => '/api'
        ).update_all(
          :path => '/ovirt-engine/api'
        )
      end
    end
  end
end
