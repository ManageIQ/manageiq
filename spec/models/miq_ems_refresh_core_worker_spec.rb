describe MiqEmsRefreshCoreWorker do
  # enable role "ems_inventory" ( .has_role_enabled? == true)
  before do
    FactoryGirl.create(:server_role, :name => 'ems_inventory')
    my_server = EvmSpecHelper.local_miq_server
    my_server.update_attributes(:role => "ems_inventory")
    my_server.activate_roles("ems_inventory")
  end

  context ".should_start_worker?" do
    context "with update_driven_refresh" do
      before do
        stub_settings_merge(
          :prototype => {
            :ems_vmware => {
              :update_driven_refresh => true
            }
          }
        )
      end

      it "should not start the worker" do
        expect(described_class.should_start_worker?).to be_falsy
      end
    end
    context "without update_driven_refresh" do
      before do
        stub_settings_merge(
          :prototype => {
            :ems_vmware => {
              :update_driven_refresh => false
            }
          }
        )
      end

      it "should not start the worker" do
        described_class.should_start_worker?
        expect(described_class.should_start_worker?).to be_truthy
      end
    end
  end
end
