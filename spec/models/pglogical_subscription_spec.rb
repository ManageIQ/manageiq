describe PglogicalSubscription do
  let(:remote_region1) { ApplicationRecord.my_region_number + 1 }
  let(:remote_region2) { ApplicationRecord.my_region_number + 2 }
  let(:subscriptions) do
    [
      {
        "subscription_name" => "region_#{remote_region1}_subscription",
        "status"            => "replicating",
        "provider_node"     => "region_#{remote_region1}",
        "provider_dsn"      => "dbname = 'vmdb\\'s_test' host='example.com' user='root' port='' password='p=as\\' s\\''",
        "slot_name"         => "pgl_vmdb_test_region_#{remote_region1}_subscripdb71d61",
        "replication_sets"  => ["miq"],
        "forward_origins"   => ["all"]
      },
      {
        "subscription_name" => "region_#{remote_region2}_subscription",
        "status"            => "disabled",
        "provider_node"     => "region_#{remote_region2}",
        "provider_dsn"      => "dbname = vmdb_test2 host=test.example.com user = postgres port=5432 fallback_application_name='bin/rails'",
        "slot_name"         => "pgl_vmdb_test_region_#{remote_region2}_subscripdb71d61",
        "replication_sets"  => ["miq"],
        "forward_origins"   => ["all"]
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

  def with_valid_schemas
    allow(EvmDatabase).to receive(:check_schema).and_return(nil)
  end

  def with_an_invalid_local_schema
    allow(EvmDatabase).to receive(:check_schema).with(no_args).and_return("Different local schema")
  end

  def with_an_invalid_remote_schema
    connection = double(:connection)
    allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(connection)
    allow(EvmDatabase).to receive(:check_schema).and_return(nil, "Different remote schema")
  end

  describe "#save!" do
    it "raises when the local schema is invalid" do
      with_an_invalid_local_schema
      sub = described_class.new(:host => "some.host.example.com")
      expect { sub.save! }.to raise_error(RuntimeError, "Different local schema")
    end

    it "raises when the remote schema is invalid" do
      with_an_invalid_remote_schema
      sub = described_class.new(:host => "some.host.example.com", :password => "1234")
      expect { sub.save! }.to raise_error(RuntimeError, "Different remote schema")
    end

    it "creates the node when there are no subscriptions" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2)
      with_valid_schemas

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

      described_class.new(:host => "test-2.example.com", :user => "root", :password => "1234").save!
    end

    it "doesnt create the node when we are already a node" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2)
      with_valid_schemas

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

      ret = described_class.new(:host => "test-2.example.com", :password => "1234", :user => "root").save!
      expect(ret).to be_an_instance_of(described_class)
    end

    it "updates the dsn when an existing subscription is saved" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscription_show_status).and_return(subscriptions.first)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      with_valid_schemas

      sub = described_class.find(:first)
      sub.host = "other-host.example.com"

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
      with_valid_schemas

      sub = described_class.find(:first)
      sub.host = "other-host.example.com"

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
      with_valid_schemas

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

      described_class.save_all!(to_save)
    end

    it "raises a combined error when some saves fail" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2, 2, 3, 3, 4, 4)
      with_valid_schemas

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

    it "removes the region authentication key if present" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions, [subscriptions.last])
      expect(pglogical).to receive(:subscription_drop).with("region_#{remote_region1}_subscription", true)

      EvmSpecHelper.create_guid_miq_server_zone
      auth = FactoryGirl.create(
        :auth_token,
        :resource_id   => remote_region.id,
        :resource_type => "MiqRegion",
        :auth_key      => "this is the encryption key!",
        :authtype      => "system_api"
      )

      sub.delete
      expect(AuthToken.find_by_id(auth.id)).to be_nil
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
  end
end
