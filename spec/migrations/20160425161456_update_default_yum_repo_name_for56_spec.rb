require_migration

describe UpdateDefaultYumRepoNameFor56 do
  let(:db_stub) { migration_stub(:MiqDatabase) }

  migration_context :up do
    it "migrates the repo data" do
      existing_repo = "cf-me-5.5-for-rhel-7-rpms rhel-server-rhscl-7-rpms"
      desired_repo  = "cf-me-5.6-for-rhel-7-rpms rhel-server-rhscl-7-rpms"
      db = db_stub.create!(:update_repo_name => existing_repo)

      migrate

      expect(db.reload.update_repo_name).to eq(desired_repo)
    end
  end

  migration_context :down do
    it "migrates the data back" do
      desired_repo  = "cf-me-5.5-for-rhel-7-rpms rhel-server-rhscl-7-rpms"
      existing_repo = "cf-me-5.6-for-rhel-7-rpms rhel-server-rhscl-7-rpms"
      db = db_stub.create!(:update_repo_name => existing_repo)

      migrate

      expect(db.reload.update_repo_name).to eq(desired_repo)
    end
  end
end
