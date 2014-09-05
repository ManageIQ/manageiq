require "spec_helper"

describe MiqDatabase do
  context ".seed" do
    it "When called multiple times should only create 1 record" do
      3.times { MiqDatabase.seed }

      expect(MiqDatabase.count).to eq(1)
    end

    context "default values" do
      it "new record" do
        MiqDatabase.seed

        db = MiqDatabase.first
        expect(db.csrf_secret_token_encrypted).to be_encrypted
        expect(db.session_secret_token_encrypted).to be_encrypted
        expect(db.update_repo_name).to eq("cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms")
        expect(db.registration_type).to eq("sm_hosted")
        expect(db.registration_server).to eq("subscription.rhn.redhat.com")
      end

      context "existing record" do
        it "will seed nil values" do
          FactoryGirl.build(:miq_database,
            :csrf_secret_token    => nil,
            :session_secret_token => nil,
            :update_repo_name     => nil
          ).save(:validate => false)

          MiqDatabase.seed

          db = MiqDatabase.first
          expect(db.csrf_secret_token_encrypted).to be_encrypted
          expect(db.session_secret_token_encrypted).to be_encrypted
          expect(db.update_repo_name).to eq("cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms")
        end

        it "will not change existing values" do
          FactoryGirl.create(:miq_database,
            :csrf_secret_token    => "abc",
            :session_secret_token => "def",
            :update_repo_name     => "ghi"
          )
          csrf, session, update_repo = MiqDatabase.all.collect { |db| [db.csrf_secret_token, db.session_secret_token, db.update_repo_name] }.first

          MiqDatabase.seed

          db = MiqDatabase.first
          expect(db.csrf_secret_token).to eq(csrf)
          expect(db.session_secret_token).to eq(session)
          expect(db.update_repo_name).to eq(update_repo)
        end
      end
    end

    context "registration_default_values" do
      it "registration_default_values method" do
        expect(MiqDatabase.registration_default_values).to be_kind_of(Hash)
      end

      it "can not be modified" do
        defaults = MiqDatabase.registration_default_values
        expect { defaults[:registration_type] = "abc" }.to raise_error(RuntimeError)
      end
    end
  end

  context "verify_credentials" do
    it "verify registration credentials" do
      MiqDatabase.seed
      EvmSpecHelper.create_guid_miq_server_zone

      MiqTask.should_receive(:wait_for_taskid).and_return(FactoryGirl.create(:miq_task, :state => "Finished"))

      MiqDatabase.first.verify_credentials(:registration)
    end
  end

  pending("New model-based-rewrite") do
    context "#vmdb_tables" do
      before(:each) do
        MiqDatabase.seed
        @db = MiqDatabase.first

        @expected_tables = %w(schema_migrations vms miq_databases)
        VmdbTable.stub(:vmdb_table_names).and_return(@expected_tables)
      end

      after(:each) do
        VmdbTable.registered.clear
      end

      it "will fetch initial tables" do
        tables = @db.vmdb_tables
        tables.collect {|t| t.name }.should have_same_elements @expected_tables
      end

      it "will create tables once" do
        @db.vmdb_tables
        VmdbTable.should_receive(:new).never
        @db.vmdb_tables
      end
    end
  end
end
