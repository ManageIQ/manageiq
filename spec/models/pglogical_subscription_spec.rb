describe PglogicalSubscription do
  let(:subscriptions) do
    [
      {
        "subscription_name" => "region_0_subscription",
        "status"            => "replicating",
        "provider_node"     => "region_0",
        "provider_dsn"      => "dbname = 'vmdb\\'s_test' host='example.com' user='root' port='' password='p=as\\' s\\''",
        "slot_name"         => "pgl_vmdb_test_region_0_subscripdb71d61",
        "replication_sets"  => ["miq"],
        "forward_origins"   => ["all"]
      },
      {
        "subscription_name" => "region_1_subscription",
        "status"            => "disabled",
        "provider_node"     => "region_1",
        "provider_dsn"      => "dbname = vmdb_test2 host=test.example.com user = postgres port=5432 fallback_application_name='bin/rails'",
        "slot_name"         => "pgl_vmdb_test_region_1_subscripdb71d61",
        "replication_sets"  => ["miq"],
        "forward_origins"   => ["all"]
      }
    ]
  end

  let(:expected_attrs) do
    [
      {
        "id"                   => "region_0_subscription",
        "status"               => "replicating",
        "dbname"               => "vmdb's_test",
        "host"                 => "example.com",
        "user"                 => "root",
        "provider_region"      => 0,
        "provider_region_name" => "The region"
      },
      {
        "id"              => "region_1_subscription",
        "status"          => "disabled",
        "dbname"          => "vmdb_test2",
        "host"            => "test.example.com",
        "user"            => "postgres",
        "port"            => 5432,
        "provider_region" => 1
      }
    ]
  end

  let(:pglogical) { double }

  before do
    FactoryGirl.create(:miq_region, :region => 0, :description => "The region")
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
    end
  end

  describe "#save!" do
    it "creates the node when there are no subscriptions" do
      allow(pglogical).to receive(:subscriptions).and_return([])
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(MiqRegionRemote).to receive(:with_remote_connection).and_yield(double(:connection))
      allow(MiqRegionRemote).to receive(:region_number_from_sequence).and_return(2)

      # node created
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

      described_class.new(:host => "test-2.example.com", :user => "root").save!
    end

    it "raises when an existing subscription is saved" do
      allow(pglogical).to receive(:subscriptions).and_return(subscriptions)
      allow(pglogical).to receive(:enabled?).and_return(true)

      sub = described_class.find(:first)

      sub.host = "other-host.example.com"
      expect { sub.save! }.to raise_error("Cannot update an existing subscription")
    end
  end

  describe "#delete" do
    it "drops the node when this is the last subscription" do
      allow(pglogical).to receive(:enabled?).and_return(true)
      allow(pglogical).to receive(:subscriptions).and_return([subscriptions.first], [])

      sub = described_class.find(:first)

      expect(pglogical).to receive(:subscription_drop).with("region_0_subscription", true)
      expect(MiqRegion).to receive(:destroy_region)
        .with(instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter), 0)
      expect(pglogical).to receive(:node_drop).with("region_#{MiqRegion.my_region_number}", true)

      sub.delete
    end
  end
end
