require_migration

describe RemoveMirroredLoggerSettings do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "removes the MirroredLogger settings but leaves others" do
      removed = settings_change_stub.create!(:key => "/log/level_kube_in_evm", :value => "info")
      settings_change_stub.create!(:key => "/log/level",      :value => "debug")
      settings_change_stub.create!(:key => "/log/level_kube", :value => "debug")

      migrate

      expect(settings_change_stub.count).to eq 2
      expect { removed.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
