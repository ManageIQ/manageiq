RSpec.describe PglogicalSubscription do
  let(:remote_region1) { ApplicationRecord.my_region_number + 1 }
  let(:remote_region2) { ApplicationRecord.my_region_number + 2 }
  let(:remote_region3) { ApplicationRecord.my_region_number + 3 }
  let(:remote_region4) { ApplicationRecord.my_region_number + 4 }
  let(:subscriptions) do
    [
      {
        "subscription_name"      => "region_#{remote_region1}_subscription",
        "database_name"          => "vmdb_production",
        "owner"                  => "root",
        "worker_count"           => 1,
        "enabled"                => true,
        "subscription_dsn"       => "dbname = 'vmdb\\'s_test' host='example.com' user='root' port='' password='p=as\\' s\\''",
        "slot_name"              => "region_#{remote_region1}_subscription",
        "publications"           => ["miq"],
        "remote_replication_lsn" => "0/420D9A0",
        "local_replication_lsn"  => "18/72DE8268"
      },
      {
        "subscription_name"      => "region_#{remote_region3}_subscription",
        "database_name"          => "vmdb_production",
        "owner"                  => "root",
        "worker_count"           => 0,
        "enabled"                => true,
        "subscription_dsn"       => "dbname=vmdb_development host=example.com user='root' port=5432",
        "slot_name"              => "region_#{remote_region3}_subscription",
        "publications"           => ["miq"],
        "remote_replication_lsn" => "0/420D9A0",
        "local_replication_lsn"  => "18/72DE8268"
      },
      {
        "subscription_name"      => "region_#{remote_region4}_subscription",
        "database_name"          => "vmdb_production",
        "owner"                  => "root",
        "worker_count"           => 4,
        "enabled"                => true,
        "subscription_dsn"       => "dbname=vmdb_production host=example.com user='root' port=5432",
        "slot_name"              => "region_#{remote_region4}_subscription",
        "publications"           => ["miq"],
        "remote_replication_lsn" => "0/420D9A0",
        "local_replication_lsn"  => "18/72DE8268"
      },
      {
        "subscription_name"      => "region_#{remote_region2}_subscription",
        "database_name"          => "vmdb_production",
        "owner"                  => "root",
        "worker_count"           => 0,
        "enabled"                => false,
        "subscription_dsn"       => "dbname = vmdb_test2 host=test.example.com user = postgres port=5432 fallback_application_name='bin/rails'",
        "slot_name"              => "region_#{remote_region2}_subscription",
        "publications"           => ["miq"],
        "remote_replication_lsn" => "1/53E9A8",
        "local_replication_lsn"  => "20/72FF8369"
      }
    ]
  end

  let(:expected_attrs) do
    [
      {
        "id"                   => "region_#{remote_region1}_subscription",
        "status"               => "replicating",
        "dbname"               => "vmdb's_test",
        "host"                 => "example.com",
        "user"                 => "root",
        "provider_region"      => remote_region1,
        "provider_region_name" => "The region"
      },
      {
        "id"              => "region_#{remote_region3}_subscription",
        "status"          => "down",
        "dbname"          => "vmdb_development",
        "host"            => "example.com",
        "user"            => "root",
        "port"            => 5432,
        "provider_region" => remote_region3
      },
      {
        "id"              => "region_#{remote_region4}_subscription",
        "status"          => "initializing",
        "dbname"          => "vmdb_production",
        "host"            => "example.com",
        "user"            => "root",
        "port"            => 5432,
        "provider_region" => remote_region4
      },
      {
        "id"              => "region_#{remote_region2}_subscription",
        "status"          => "disabled",
        "dbname"          => "vmdb_test2",
        "host"            => "test.example.com",
        "user"            => "postgres",
        "port"            => 5432,
        "provider_region" => remote_region2
      }
    ]
  end

  let(:pglogical)      { double }
  let!(:remote_region) do
    FactoryBot.create(
      :miq_region,
      :id          => ApplicationRecord.id_in_region(remote_region1, 1),
      :region      => remote_region1,
      :description => "The region"
    )
  end

  before do
    allow(described_class).to receive(:pglogical).and_return(pglogical)
  end

  describe ".all" do
    it "retrieves all records with records" do
      with_records
      actual_attrs = described_class.all.map(&:attributes)
      expect(actual_attrs).to match_array(expected_attrs)
    end

    it "supports find(:all) with records" do
      with_records
      actual_attrs = described_class.find(:all).map(&:attributes)
      expect(actual_attrs).to match_array(expected_attrs)
    end

    it "retrieves no records with no records" do
      with_no_records
      expect(described_class.all).to be_empty
      expect(described_class.find(:all)).to be_empty
    end
  end

  describe ".first" do
    it "retrieves the first record with records" do
      with_records
      rec = described_class.find(:first)
      expect(rec.attributes).to eq(expected_attrs.first)
    end

    it "returns nil with no records" do
      with_no_records
      expect(described_class.find(:first)).to be_nil
    end
  end

  describe ".last" do
    it "retrieves the last record with :last" do
      with_records
      rec = described_class.find(:last)
      expect(rec.attributes).to eq(expected_attrs.last)
    end

    it "returns nil with :last" do
      with_no_records
      expect(described_class.find(:last)).to be_nil
    end
  end

  describe ".find" do
    it "retrieves the specified record with records" do
      with_records
      expected = expected_attrs.first
      rec = described_class.find(expected["id"])
      expect(rec.attributes).to eq(expected)
    end

    it "raises when no record is found" do
      with_no_records
      expect { described_class.find("doesnt_exist") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".lookup_by_id" do
    it "returns the specified record with records" do
      with_records
      expected = expected_attrs.first
      rec = described_class.lookup_by_id(expected["id"])
      expect(rec.attributes).to eq(expected)
    end

    it "returns nil without records" do
      with_no_records
      expect(described_class.lookup_by_id("some_subscription")).to be_nil
    end
  end

  describe "#save!" do
    context "failover monitor reloading" do
      let(:sub) { described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234") }
      before do
        with_no_records
        allow(pglogical).to receive(:create_subscription).and_return(double(:check => nil))
        allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
        allow(sub).to receive(:remote_region_number).and_return(remote_region1)
      end

      it "doesn't queue a message to restart the failover monitor service when passed 'false'" do
        sub.save!(false)
        expect(MiqQueue.where(:method_name => "restart_failover_monitor_service")).to be_empty
      end

      it "queues a message to restart the failover monitor when called without args" do
        sub.save!
        expect(MiqQueue.where(:method_name => "restart_failover_monitor_service").count).to eq(1)
      end
    end

    it "raises when subscribing to the same region" do
      with_no_records
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.new(:host => "some.host.example.com", :password => "password")
      expect { sub.save! }.to raise_error(RuntimeError, "Subscriptions cannot be created to the same region as the current region")
    end

    it "does not raise when subscribing to a different region" do
      with_no_records
      allow(pglogical).to receive(:create_subscription).and_return(double(:check => nil))
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234")
      allow(sub).to receive(:remote_region_number).and_return(remote_region1)

      expect { sub.save! }.not_to raise_error
    end

    it "creates the subscription" do
      with_no_records
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2)

      dsn = {
        :host     => "test-2.example.com",
        :user     => "root",
        :password => "1234"
      }
      expect(pglogical).to receive(:create_subscription).with("region_2_subscription", dsn, ['miq']).and_return(double(:check => nil))

      sub = described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234")
      allow(sub).to receive(:assert_different_region!)

      sub.save!
      expect(sub).to be_an_instance_of(described_class)
    end

    it "updates the dsn when an existing subscription is saved" do
      with_records
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.find(:first)
      sub.host = "other-host.example.com"
      allow(sub).to receive(:assert_different_region!)

      new_dsn = {
        :host     => "other-host.example.com",
        :dbname   => sub.dbname,
        :user     => sub.user,
        :password => "p=as\' s\'"
      }

      expect(pglogical).to receive(:set_subscription_conninfo).with(sub.id, new_dsn)
      expect(sub.save!).to eq(sub)
    end
  end

  describe ".delete_all" do
    let(:subscription1) { double }
    let(:subscription2) { double }

    after do
      expect(MiqQueue.where(:method_name => "restart_failover_monitor_service").count).to eq(1)
    end

    it "deletes all subscriptions if no parameter passed" do
      allow(described_class).to receive(:find).with(:all).and_return([subscription1, subscription2])
      expect(subscription1).to receive(:delete)
      expect(subscription2).to receive(:delete)
      described_class.delete_all
    end

    it "only deletes subscriptions listed in parameter if parameter passed" do
      expect(subscription1).to receive(:delete)
      expect(subscription2).not_to receive(:delete)
      described_class.delete_all([subscription1])
    end
  end

  describe ".save_all!" do
    after do
      expect(MiqQueue.where(:method_name => "restart_failover_monitor_service").count).to eq(1)
    end

    it "saves each of the objects" do
      with_no_records
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2, 2, 3, 3)

      dsn2 = {
        :host     => "test-2.example.com",
        :user     => "root",
        :password => "1234"
      }
      expect(pglogical).to receive(:create_subscription).with("region_2_subscription", dsn2, ['miq']).and_return(double(:check => nil))

      dsn3 = {
        :host     => "test-3.example.com",
        :user     => "miq",
        :password => "1234"
      }
      expect(pglogical).to receive(:create_subscription).with("region_3_subscription", dsn3, ['miq']).and_return(double(:check => nil))

      to_save = []
      to_save << described_class.new(dsn2)
      to_save << described_class.new(dsn3)
      to_save.each { |s| allow(s).to receive(:assert_different_region!) }

      described_class.save_all!(to_save)
    end

    it "raises a combined error when some saves fail" do
      with_no_records
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2, 2, 3, 3, 4, 4)

      expect(pglogical).to receive(:create_subscription).ordered.and_raise(PG::Error.new("Error one"))
      dsn3 = {
        :host     => "test-3.example.com",
        :user     => "miq",
        :password => "1234"
      }
      expect(pglogical).to receive(:create_subscription).ordered.with("region_3_subscription", dsn3, ['miq']).and_return(double(:check => nil))
      expect(pglogical).to receive(:create_subscription).ordered.and_raise("Error two")

      to_save = []
      to_save << described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234")
      to_save << described_class.new(:host => "test-3.example.com", :user => "miq", :password => "1234")
      to_save << described_class.new(:host => "test-4.example.com", :user => "miq", :password => "1234")
      to_save.each { |s| allow(s).to receive(:assert_different_region!) }

      expect { described_class.save_all!(to_save) }.to raise_error("Failed to save subscription " \
        "to test-2.example.com: Error one\nFailed to save subscription to test-4.example.com: Error two")
    end
  end

  describe "#delete" do
    let(:sub) { described_class.find(:first) }

    it "drops the subscription" do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first], [])

      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true)
      expect(MiqRegion).to receive(:destroy_region)
        .with(instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter), remote_region1)

      sub.delete
    end

    it "doesn't queue a failover monitor restart when passed false" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions, [subscriptions.last])

      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true)
      expect(MiqQueue.where(:method_name => "restart_failover_monitor_service")).to be_empty

      sub.delete(false)
    end

    it "removes the subscription when the publisher is unreachable" do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first], [])
      exception = PG::InternalError.new(<<~MESSAGE)
        ERROR:  could not connect to publisher when attempting to drop the replication slot "region_#{remote_region1}_subscription"
        DETAIL:  The error was: could not connect to server: Connection refused
                Is the server running on host "example.com" and accepting
                TCP/IP connections on port 5432?
        HINT:  Use ALTER SUBSCRIPTION ... SET (slot_name = NONE) to disassociate the subscription from the slot.
      MESSAGE

      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true).ordered.and_raise(exception)
      expect(sub).to receive(:disable)
      expect(pglogical).to receive(:alter_subscription_options).with(sub.id, "slot_name" => "NONE")
      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true).ordered
      expect(MiqRegion).to receive(:destroy_region)
        .with(instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter), remote_region1)

      sub.delete
    end

    it "removes the subscription when the replication slot is missing" do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first], [])
      exception = PG::InternalError.new(<<~MESSAGE)
        ERROR:  could not drop the replication slot "NONE" on publisher
        DETAIL:  The error was: ERROR:  replication slot "NONE" does not exist
      MESSAGE

      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true).ordered.and_raise(exception)
      expect(sub).to receive(:disable)
      expect(pglogical).to receive(:alter_subscription_options).with(sub.id, "slot_name" => "NONE")
      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true).ordered
      expect(MiqRegion).to receive(:destroy_region)
        .with(instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter), remote_region1)

      sub.delete
    end

    it "re-raises other PG::InternalErrors" do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first], [])
      exception = PG::InternalError.new(<<~MESSAGE)
        ERROR:  badness happened :(
      MESSAGE

      expect(pglogical).to receive(:drop_subscription).with("region_#{remote_region1}_subscription", true).ordered.and_raise(exception)

      expect { sub.delete }.to raise_error(exception)
    end
  end

  describe "#validate" do
    it "validates existing subscriptions with new parameters" do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first])

      sub = described_class.find(:first)
      expect(sub.host).to eq "example.com"
      expect(sub.port).to be_blank
      expect(sub.user).to eq "root"

      expect(MiqRegionRemote).to receive(:validate_connection_settings)
        .with("another-example.net", 5423, "root", "p=as' s'", "vmdb's_test")
      sub.validate('host' => "another-example.net", 'port' => 5423)
    end

    it "validates a subscription that has not been saved without accessing the database" do
      sub = described_class.new
      sub.host     = "my.example.com"
      sub.password = "thepassword"
      sub.user     = "root"
      sub.dbname   = "vmdb_production"

      expect(MiqRegionRemote).to receive(:validate_connection_settings)
        .with("my.example.com", nil, "root", "thepassword", "vmdb_production")
      sub.validate
    end

    it "validates connection parameters without accessing database or initializing subscription parameters" do
      sub = described_class.new

      expect(MiqRegionRemote).to receive(:validate_connection_settings)
        .with("my.example.com", nil, "root", "mypass", "vmdb_production")
      sub.validate('host' => "my.example.com", 'user' => "root", 'password' => "mypass", 'dbname' => "vmdb_production")
    end
  end

  describe "#backlog" do
    let(:remote_connection) { double(:remote_connection) }

    before do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first])
    end

    it "returns the correct value" do
      expect(MiqRegionRemote).to receive(:with_remote_connection).and_yield(remote_connection)
      expect(remote_connection).to receive(:xlog_location).and_return("0/42108F8")

      expect(described_class.first.backlog).to eq(12_120)
    end

    it "returns nil if error raised inside" do
      expect(MiqRegionRemote).to receive(:with_remote_connection).and_raise(PG::Error)

      expect(described_class.first.backlog).to be nil
    end

    it 'does not attempt to calculate backlog and returns nil unless subscription status is "replicating"' do
      allow(described_class).to receive(:subscription_status).and_return("down")

      expect(remote_connection).not_to receive(:xlog_location)
      expect(described_class.first.backlog).to be nil
    end
  end

  private

  def with_records
    allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
  end

  def with_no_records
    allow(pglogical).to receive(:subscriptions).and_return([])
  end
end
