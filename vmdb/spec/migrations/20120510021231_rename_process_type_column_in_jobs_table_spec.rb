require "spec_helper"
require Rails.root.join("db/migrate/20120510021231_rename_process_type_column_in_jobs_table.rb")

describe RenameProcessTypeColumnInJobsTable do
  migration_context :up do
    class RenameProcessTypeColumnInJobsTable::Job < ActiveRecord::Base; end;
    job_stub = RenameProcessTypeColumnInJobsTable::Job

    it "HostRemoteDeploy" do
      job_stub.create!(:process_type => 'HostRemoteDeploy')

      migrate

      job_stub.first.type.should == "HostRemoteDeploy"
    end
  end
end
