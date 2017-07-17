describe MiqEmsRefreshCoreWorker do
  context "update_driven_refresh" do
    before do
      stub_settings_merge(
        :prototype => {
          :ems_vmware => {
            :update_driven_refresh => true
          }
        }
      )
    end

    it ".has_required_role?" do
      expect(described_class.has_required_role?).to be_falsy
    end
  end
end
