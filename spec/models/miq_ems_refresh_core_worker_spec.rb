describe MiqEmsRefreshCoreWorker do
  # enable role "ems_inventory" ( .has_required_role? == true)
  before do
    FactoryGirl.create(:server_role, :name => 'ems_inventory')
    my_server = EvmSpecHelper.local_miq_server
    my_server.update_attributes(:role => "ems_inventory")
    my_server.activate_roles("ems_inventory")
  end

  context ".has_required_role?" do
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
        expect(described_class.has_required_role?).to be_falsy
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

      it "should start the worker" do
        expect(described_class.has_required_role?).to be_truthy
      end
      context "without role" do
        before do
          MiqServer.my_server(true).deactivate_roles("ems_inventory")
        end
        it "should not start the worker" do
          expect(described_class.has_required_role?).to be_falsy
        end
      end
    end
  end
end
