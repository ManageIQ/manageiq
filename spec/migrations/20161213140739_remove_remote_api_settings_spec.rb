require_migration

describe RemoveRemoteApiSettings do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "removes the remote api authentication settings" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/webservices/remote_miq_api/user",
        :value         => "admin"
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/webservices/remote_miq_api/password",
        :value         => "thepassword"
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/api/token_ttl",
        :value         => "5.minutes"
      )

      migrate

      expect(settings_change_stub.where("key LIKE ?", described_class::API_AUTH_KEY).count).to eq 0
      expect(settings_change_stub.count).to eq 1

      kept_change = settings_change_stub.first
      expect(kept_change.resource_type).to eq("MiqServer")
      expect(kept_change.key).to eq("/api/token_ttl")
      expect(kept_change.value).to eq("5.minutes")
    end
  end
end
