describe MiqRegion do
  context "after seeding" do
    before(:each) do
      MiqRegion.seed
    end

    it "should increment naming sequence number after each call" do
      expect(MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming")).to eq(1)
      expect(MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming")).to eq(2)
      expect(MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming")).to eq(1)
      expect(MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming")).to eq(2)
    end

    context "with cloud and infra EMSes" do
      before :each do
        guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
        ems_vmware = FactoryGirl.create(:ems_vmware, :zone => zone)
        ems_openstack = FactoryGirl.create(:ems_openstack, :zone => zone)
        ems_redhat = FactoryGirl.create(:ems_redhat, :zone => zone)

        @ems_clouds = [ems_openstack]
        @ems_infras = [ems_redhat, ems_vmware]

        @region = MiqRegion.my_region
      end

      it "should be able to return the list of ems_clouds" do
        expect(@region.ems_clouds).to include(*@ems_clouds)
        expect(@region.ems_clouds).not_to include(*@ems_infras)
      end

      it "should be able to return the list of ems_infras" do
        expect(@region.ems_infras).to include(*@ems_infras)
        expect(@region.ems_infras).not_to include(*@ems_clouds)
      end
    end
  end

  it ".log_not_under_management" do
    MiqRegion.seed
    FactoryGirl.create(:host_vmware)
    FactoryGirl.create(:vm_vmware)
    expect($log).to receive(:info).with(/VMs: \[1\], Hosts: \[1\]/)
    described_class.log_not_under_management("")
  end

  context ".seed" do
    before do
      @region_number = 99
      allow(MiqRegion).to receive_messages(:my_region_number => @region_number)
      MiqRegion.seed
    end

    include_examples ".seed called multiple times"

    it "should have the expected region number" do
      expect(MiqRegion.first.region).to eq(@region_number)
    end

    it "replaces deleted current region" do
      MiqRegion.where(:region => @region_number).destroy_all
      expect(MiqRegion.count).to eq(0)
      MiqRegion.seed
      expect(MiqRegion.first.region).to eq(@region_number)
    end

    it "raises Exception if db region_id doesn't match my_region_number" do
      @db = FactoryGirl.create(:miq_database)
      allow(MiqRegion).to receive_messages(:my_region_number => @region_number + 1)
      expect { MiqRegion.seed }.to raise_error(Exception)
    end
  end

  describe ".replication_type" do
    it "returns :global when configured as a pglogical subscriber" do
      pgl = double(:provider? => false, :subscriber? => true, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(described_class.replication_type).to eq(:global)
    end

    it "returns :remote when configured as a pglogical provider" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(described_class.replication_type).to eq(:remote)
    end

    it "returns :none if pglogical is not configured" do
      pgl = double(:provider? => false, :subscriber? => false, :node? => false)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(described_class.replication_type).to eq(:none)
    end
  end

  describe ".replication_type=" do
    it "returns the replication_type, even when unchanged" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)
      expect(described_class.replication_type = :remote).to eq :remote
    end

    it "destroys the provider when transition is :remote -> :none" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(pgl).to receive(:destroy_provider)

      expect(described_class.replication_type = :none).to eq :none
    end

    it "deletes all subscriptions when transition is :global -> :none" do
      pgl = double(:provider? => false, :subscriber? => true, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(PglogicalSubscription).to receive(:delete_all)

      expect(described_class.replication_type = :none).to eq :none
    end

    it "creates a new provider when transition is :none -> :remote" do
      pgl = double(:provider? => false, :subscriber? => false, :node? => false)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(pgl).to receive(:configure_provider)

      expect(described_class.replication_type = :remote).to eq :remote
    end

    it "deletes all subscriptions and creates a new provider when transition is :global -> :remote" do
      pgl = double(:provider? => false, :subscriber? => true, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(PglogicalSubscription).to receive(:delete_all)
      expect(pgl).to receive(:configure_provider)

      expect(described_class.replication_type = :remote).to eq :remote
    end

    it "destroys the provider when transition is :remote -> :global" do
      pgl = double(:provider? => true, :subscriber? => false, :node? => true)
      allow(MiqPglogical).to receive(:new).and_return(pgl)

      expect(pgl).to receive(:destroy_provider)

      expect(described_class.replication_type = :global).to eq :global
    end
  end
end
