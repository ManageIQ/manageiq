require "spec_helper"
require Rails.root.join("db/migrate/20140905020643_update_default_registration_channel_names")

class MiqDatabase < ActiveRecord::Base; end

describe UpdateDefaultRegistrationChannelNames do
  let(:miq_database_stub) { migration_stub(:MiqDatabase) }

  migration_context :up do
    it "Updates the default registration channel names for v5.3" do
      miq_database_stub.create!(:update_repo_name => "cf-me-5.2-for-rhel-6-rpms")

      expect(MiqDatabase.count).to eq(1)
      expect(miq_database_stub.first.update_repo_name).to eq("cf-me-5.2-for-rhel-6-rpms")

      migrate

      expect(miq_database_stub.first.update_repo_name).to eq("cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms")
    end

    it "Skips non-default channels" do
      miq_database_stub.create!(:update_repo_name => "not-default")

      expect(MiqDatabase.count).to eq(1)
      expect(miq_database_stub.first.update_repo_name).to eq("not-default")

      migrate

      expect(miq_database_stub.first.update_repo_name).to eq("not-default")
    end
  end
end
