shared_context :shared_storage_manager_context do |t|
  before :each do
    @ems_cloud = FactoryGirl.create("ems_#{t}".to_sym,
                                    :name => "Test Cloud Manager")
    if t == 'openstack'
      @swift_manager    = @cinder_manager = nil
      @storage_managers = @ems_cloud.storage_managers
      @storage_managers.each do |sm|
        if sm.type == "ManageIQ::Providers::StorageManager::SwiftManager"
          @swift_manager = sm
        else
          @cinder_manager = sm
        end
      end
    end
    @ems = @cinder_manager
  end
end
