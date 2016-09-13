require_migration

describe UpdateDefaultYumRepoNameFor57 do
  let(:db_stub)  { migration_stub(:MiqDatabase) }
  let(:old_repo) { "cf-me-5.6-for-rhel-7-rpms rhel-server-rhscl-7-rpms" }
  let(:new_repo) { "cf-me-5.7-for-rhel-7-rpms rhel-server-rhscl-7-rpms" }

  migration_context :up do
    it "migrates the repo data" do
      db = db_stub.create!(:update_repo_name => old_repo)

      migrate

      expect(db.reload.update_repo_name).to eq(new_repo)
    end
  end

  migration_context :down do
    it "migrates the data back" do
      db = db_stub.create!(:update_repo_name => new_repo)

      migrate

      expect(db.reload.update_repo_name).to eq(old_repo)
    end
  end
end
