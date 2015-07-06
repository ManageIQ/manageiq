require "spec_helper"
require Rails.root.join("db/migrate/20150316175916_update_miq_database_default_update_repo_name")

describe UpdateMiqDatabaseDefaultUpdateRepoName do
  let(:db_stub) { migration_stub(:MiqDatabase) }

  migration_context :up do
    [
      ["Satellite 5 without scl repo", "rhel-x86_64-server-6-cf-me-3",                                "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1"],
      ["Satellite 5 with scl repo",    "rhel-x86_64-server-6-cf-me-3.1 rhel-x86_64-server-6-rhscl-1", "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1"],
      ["Satellite 6",                  "cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms",          "cf-me-5.4-for-rhel-6-rpms rhel-server-rhscl-6-rpms"],
    ].each do |name, existing_repo, desired_repo|
      it name do
        db = db_stub.create!(:update_repo_name => existing_repo)

        migrate

        expect(db.reload.update_repo_name).to eq(desired_repo)
      end
    end
  end

  migration_context :down do
    [
      ["Satellite 5", "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1", "rhel-x86_64-server-6-cf-me-3.1 rhel-x86_64-server-6-rhscl-1"],
      ["Satellite 6", "cf-me-5.4-for-rhel-6-rpms rhel-server-rhscl-6-rpms",          "cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms"],
    ].each do |name, existing_repo, desired_repo|
      it name do
        db = db_stub.create!(:update_repo_name => existing_repo)

        migrate

        expect(db.reload.update_repo_name).to eq(desired_repo)
      end
    end
  end
end
