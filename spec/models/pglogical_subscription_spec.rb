describe PglogicalSubscription do
  let(:remote_region1) { ApplicationRecord.my_region_number + 1 }
  let(:remote_region2) { ApplicationRecord.my_region_number + 2 }
  let(:subscriptions) do
    [
      {
        "subscription_name"      => "region_#{remote_region1}_subscription",
        "status"                 => "replicating",
        "provider_node"          => "region_#{remote_region1}",
        "provider_dsn"           => "dbname = 'vmdb\\'s_test' host='example.com' user='root' port='' password='p=as\\' s\\''",
        "slot_name"              => "pgl_vmdb_test_region_#{remote_region1}_subscripdb71d61",
        "replication_sets"       => ["miq"],
        "forward_origins"        => ["all"],
        "remote_replication_lsn" => "0/420D9A0",
        "local_replication_lsn"  => "18/72DE8268"
      },
      {
        "subscription_name"      => "region_#{remote_region2}_subscription",
        "status"                 => "disabled",
        "provider_node"          => "region_#{remote_region2}",
        "provider_dsn"           => "dbname = vmdb_test2 host=test.example.com user = postgres port=5432 fallback_application_name='bin/rails'",
        "slot_name"              => "pgl_vmdb_test_region_#{remote_region2}_subscripdb71d61",
        "replication_sets"       => ["miq"],
        "forward_origins"        => ["all"],
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
    FactoryGirl.create(
      :miq_region,
      :id          => ApplicationRecord.id_in_region(remote_region1, 1),
      :region      => remote_region1,
      :description => "The region"
    )
  end

  before do
    allow(described_class).to receive(:pglogical).and_return(pglogical)
  end

  describe ".find" do
    context "with records" do
      before do
        allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
        allow(pglogical).to receive(:enabled?).and_return(true)
      end

      it "retrieves all the records with :all" do
        actual_attrs = described_class.find(:all).map(&:attributes)
        expect(actual_attrs).to match_array(expected_attrs)
      end

      it "retrieves the first record with :first" do
        rec = described_class.find(:first)
        expect(rec.attributes).to eq(expected_attrs.first)
      end

      it "retrieves the last record with :last" do
        rec = described_class.find(:last)
        expect(rec.attributes).to eq(expected_attrs.last)
      end

      it "retrieves the specified record with an id" do
        expected = expected_attrs.first
        rec = described_class.find(expected["id"])
        expect(rec.attributes).to eq(expected)
      end

      it "raises when no record is found with an id" do
        expect { described_class.find("doesnt_exist") }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with no records" do
      before do
        allow(pglogical).to receive(:subscriptions).and_return([])
        allow(pglogical).to receive(:enabled?).and_return(true)
      end

      it "returns an empty array with :all" do
        expect(described_class.find(:all)).to be_empty
      end

      it "returns nil with :first" do
        expect(described_class.find(:first)).to be_nil
      end

      it "returns nil with :last" do
        expect(described_class.find(:last)).to be_nil
      end

      it "raises with an id" do
        expect { described_class.find("doesnt_exist") }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with pglogical disabled" do
      before do
        allow(pglogical).to receive(:enabled?).and_return(false)
      end

      it "returns an empty array with :all" do
        expect(described_class.find(:all)).to be_empty
      end

      it "returns nil with :first" do
        expect(described_class.find(:first)).to be_nil
      end

      it "returns nil with :last" do
        expect(described_class.find(:last)).to be_nil
      end

      it "raises with an id" do
        expect { described_class.find("doesnt_exist") }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe ".find_by_id" do
    it "returns the specified record with records" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
      allow(pglogical).to receive(:enabled?).and_return(true)

      expected = expected_attrs.first
      rec = described_class.find_by_id(expected["id"])
      expect(rec.attributes).to eq(expected)
    end

    it "returns nil without records" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)

      expect(described_class.find_by_id("some_subscription")).to be_nil
    end

    it "returns nil with pglogical disabled" do
      allow(pglogical).to receive(:enabled?).and_return(false)
      expect(described_class.find_by_id("some_subscription")).to be_nil
    end
  end

  describe "#save!" do
    it "raises when subscribing to the same region" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.new(:host => "some.host.example.com")
      expect { sub.save! }.to raise_error(RuntimeError, "Subscriptions cannot be created to the same region as the current region")
    end

    it "does not raise when subscribing to a different region" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)
      allow(pglogical).to receive(:subscription_create).and_return(double(:check => nil))
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234")
      allow(sub).to receive(:remote_region_number).and_return(remote_region1)
      allow(sub).to receive(:ensure_node_created).and_return(true)

      expect { sub.save! }.not_to raise_error
    end

    it "creates the node when there are no subscriptions" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2)

      # node created if we are not already a node
      expect(MiqPglogical).to receive(:new).and_return(double(:node? => false))
      expect(pglogical).to receive(:enable)
      expect(pglogical).to receive(:node_create).and_return(double(:check => nil))

      # subscription is created
      expect(pglogical).to receive(:subscription_create) do |name, dsn, replication_sets, sync_structure|
        expect(name).to eq("region_2_subscription")
        expect(dsn).to include("host='test-2.example.com'")
        expect(dsn).to include("user='root'")
        expect(replication_sets).to eq(['miq'])
        expect(sync_structure).to be false
      end.and_return(double(:check => nil))

      sub = described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234")
      allow(sub).to receive(:assert_different_region!)

      sub.save!
    end

    it "doesnt create the node when we are already a node" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2)

      # node not created if we are already a node
      expect(MiqPglogical).to receive(:new).and_return(double(:node? => true))
      expect(pglogical).not_to receive(:enable)
      expect(pglogical).not_to receive(:node_create)

      # subscription is created
      expect(pglogical).to receive(:subscription_create) do |name, dsn, replication_sets, sync_structure|
        expect(name).to eq("region_2_subscription")
        expect(dsn).to include("host='test-2.example.com'")
        expect(dsn).to include("user='root'")
        expect(replication_sets).to eq(['miq'])
        expect(sync_structure).to be false
      end.and_return(double(:check => nil))

      sub = described_class.new(:host => "test-2.example.com", :password => "1234", :user => "root")
      allow(sub).to receive(:assert_different_region!)

      sub.save!
      expect(sub).to be_an_instance_of(described_class)
    end

    it "updates the dsn when an existing subscription is saved" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.find(:first)
      sub.host = "other-host.example.com"
      allow(sub).to receive(:assert_different_region!)

      expect(pglogical).to receive(:subscription_disable).with(sub.id)
        .and_return(double(:check => nil))
      expect(pglogical).to receive(:node_dsn_update) do |provider_node_name, new_dsn|
        expect(provider_node_name).to eq("region_#{remote_region1}")
        expect(new_dsn).to include("host='other-host.example.com'")
        expect(new_dsn).to include("dbname='vmdb\\'s_test'")
        expect(new_dsn).to include("user='root'")
        expect(new_dsn).to include("password='p=as\\' s\\''")
      end
      expect(pglogical).to receive(:subscription_enable).with(sub.id)
        .and_return(double(:check => nil))

      expect(sub.save!).to eq(sub)
    end

    it "reenables the subscription when the dsn fails to save" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))

      sub = described_class.find(:first)
      sub.host = "other-host.example.com"
      allow(sub).to receive(:assert_different_region!)

      expect(pglogical).to receive(:subscription_disable).with(sub.id)
        .and_return(double(:check => nil))
      expect(pglogical).to receive(:node_dsn_update).and_raise("Some Error")
      expect(pglogical).to receive(:subscription_enable).with(sub.id)
        .and_return(double(:check => nil))

      expect { sub.save! }.to raise_error(RuntimeError, "Some Error")
    end
  end

  describe ".save_all!" do
    it "saves each of the objects" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2, 2, 3, 3)

      # node created
      allow(pglogical).to receive(:enable)
      allow(pglogical).to receive(:node_create).and_return(double(:check => nil))

      # subscription is created
      expect(pglogical).to receive(:subscription_create) do |name, dsn, replication_sets, sync_structure|
        expect(name).to eq("region_2_subscription")
        expect(dsn).to include("host='test-2.example.com'")
        expect(dsn).to include("user='root'")
        expect(replication_sets).to eq(['miq'])
        expect(sync_structure).to be false
      end.and_return(double(:check => nil))

      expect(pglogical).to receive(:subscription_create) do |name, dsn, replication_sets, sync_structure|
        expect(name).to eq("region_3_subscription")
        expect(dsn).to include("host='test-3.example.com'")
        expect(dsn).to include("user='miq'")
        expect(replication_sets).to eq(['miq'])
        expect(sync_structure).to be false
      end.and_return(double(:check => nil))

      to_save = []
      to_save << described_class.new(:host => "test-2.example.com", :password => "1234", :user => "root")
      to_save << described_class.new(:host => "test-3.example.com", :password => "1234", :user => "miq")
      to_save.each { |s| allow(s).to receive(:assert_different_region!) }

      described_class.save_all!(to_save)
    end

    it "raises a combined error when some saves fail" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2, 2, 3, 3, 4, 4)

      # node created
      allow(pglogical).to receive(:enable)
      allow(pglogical).to receive(:node_create).and_return(double(:check => nil))

      # subscription is created
      expect(pglogical).to receive(:subscription_create).ordered.and_raise(PG::Error.new("Error one"))
      expect(pglogical).to receive(:subscription_create) do |name, dsn, replication_sets, sync_structure|
        expect(name).to eq("region_3_subscription")
        expect(dsn).to include("host='test-3.example.com'")
        expect(dsn).to include("user='miq'")
        expect(replication_sets).to eq(['miq'])
        expect(sync_structure).to be false
      end.ordered.and_return(double(:check => nil))
      expect(pglogical).to receive(:subscription_create).ordered.and_raise("Error two")

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
    before do
      allow(pglogical).to receive(:enabled?).and_return(true)
    end

    let(:sub) { described_class.find(:first) }

    it "drops the node when this is the last subscription" do
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first], [])

      expect(pglogical).to receive(:subscription_drop).with("region_#{remote_region1}_subscription", true)
      expect(MiqRegion).to receive(:destroy_region)
        .with(instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter), remote_region1)
      expect(pglogical).to receive(:node_drop).with("region_#{MiqRegion.my_region_number}", true)
      expect(pglogical).to receive(:disable)

      sub.delete
    end
  end

  describe "#validate" do
    it "validates existing subscriptions with new parameters" do
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first])
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)

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

      expect(pglogical).not_to receive(:subscription_show_status)
      expect(MiqRegionRemote).to receive(:validate_connection_settings)
        .with("my.example.com", nil, "root", "thepassword", "vmdb_production")
      sub.validate
    end

    it "validates connection parameters without accessing database or initializing subscription parameters" do
      sub = described_class.new

      expect(pglogical).not_to receive(:subscription_show_status)
      expect(MiqRegionRemote).to receive(:validate_connection_settings)
        .with("my.example.com", nil, "root", "mypass", "vmdb_production")
      sub.validate('host' => "my.example.com", 'user' => "root", 'password' => "mypass", 'dbname' => "vmdb_production")
    end
  end

  describe "#backlog" do
    let(:remote_connection) { double(:remote_connection) }

    before do
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first])
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)
    end

    it "returns the correct value" do
      expect(MiqRegionRemote).to receive(:with_remote_connection).and_yield(remote_connection)
      expect(remote_connection).to receive(:xlog_location).and_return("0/42108F8")

      expect(described_class.first.backlog).to eq(12_120)
    end

    it "returns nill if error raised inside" do
      expect(MiqRegionRemote).to receive(:with_remote_connection).and_raise(PG::Error)

      expect(described_class.first.backlog).to be nil
    end
  end
end
