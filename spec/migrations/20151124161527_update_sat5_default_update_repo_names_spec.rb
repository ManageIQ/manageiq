require "spec_helper"
require_migration

describe UpdateSat5DefaultUpdateRepoNames do
  let(:db_stub) { migration_stub(:MiqDatabase) }

  migration_context :up do
    [
      ["Satellite 5 from old", "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1", "rhel-x86_64-server-7-cf-me-4.0 rhel-x86_64-server-7-rhscl-1"],
      ["Satellite 5 from empty", "", "rhel-x86_64-server-7-cf-me-4.0 rhel-x86_64-server-7-rhscl-1"],
    ].each do |name, existing_repo, desired_repo|
      it name do
        db = db_stub.create!(:update_repo_name => existing_repo)

        migrate

        expect(db.reload.update_repo_name).to eq(desired_repo)
      end
    end
  end

  migration_context :down do
    it "restores the old sat5 repos" do
      existing_repo = "rhel-x86_64-server-7-cf-me-4.0 rhel-x86_64-server-7-rhscl-1"
      desired_repo  = "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1"
      db = db_stub.create!(:update_repo_name => existing_repo)

      migrate

      expect(db.reload.update_repo_name).to eq(desired_repo)
    end
  end
end
