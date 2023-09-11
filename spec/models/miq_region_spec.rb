RSpec.describe MiqRegion do
  subject { region }

  include_examples "MiqPolicyMixin"

  let(:region) { FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number) }
  # the first id from a region other than ours
  let(:external_region_id) do
    remote_region_number = ApplicationRecord.my_region_number + 1
    ApplicationRecord.region_to_range(remote_region_number).first
  end
  context "after seeding" do
    it "should increment naming sequence number after each call" do
      expect(MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming")).to eq(1)
      expect(MiqRegion.my_region.next_naming_sequence("namingtest$n{3}", "naming")).to eq(2)
      expect(MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming")).to eq(1)
      expect(MiqRegion.my_region.next_naming_sequence("anothertest$n{3}", "naming")).to eq(2)
    end

    context "with cloud and infra EMSes" do
      before do
        zone = EvmSpecHelper.local_miq_server.zone
        ems_vmware = FactoryBot.create(:ems_vmware, :zone => zone)
        ems_openstack = FactoryBot.create(:ems_openstack, :zone => zone)
        ems_redhat = FactoryBot.create(:ems_redhat, :zone => zone)

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

  context ".seed" do
    before do
      MiqRegion.destroy_all
      @region_number = 99
      allow(MiqRegion).to receive_messages(:my_region_number => @region_number)
      MiqRegion.seed
    end

    include_examples ".seed called multiple times", 1

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
      @db = FactoryBot.create(:miq_database)
      allow(MiqRegion).to receive_messages(:my_region_number => @region_number + 1)
      expect { MiqRegion.seed }.to raise_error(Exception)
    end
  end

  describe "#api_system_auth_token" do
    it "generates the token correctly" do
      user = "admin"
      server = FactoryBot.create(:miq_server, :has_active_webservices => true)

      token = region.api_system_auth_token(user)
      token_hash = YAML.load(ManageIQ::Password.decrypt(token))

      expect(token_hash[:server_guid]).to eq(server.guid)
      expect(token_hash[:userid]).to eq(user)
      expect(token_hash[:timestamp]).to be > 5.minutes.ago.utc
    end
  end

  describe "#vms" do
    it "brings them back" do
      FactoryBot.create(:vm_vmware, :id => external_region_id)
      vm = FactoryBot.create(:vm_vmware)
      FactoryBot.create(:template_vmware)

      expect(region.vms).to eq([vm])
    end
  end

  describe "#miq_templates" do
    it "brings them back" do
      FactoryBot.create(:vm_vmware, :id => external_region_id)
      FactoryBot.create(:vm_vmware)
      t = FactoryBot.create(:template_vmware)

      expect(region.miq_templates).to eq([t])
    end
  end

  describe "#vms_and_templates" do
    it "brings them back" do
      FactoryBot.create(:vm_vmware, :id => external_region_id)
      vm = FactoryBot.create(:vm_vmware)
      t = FactoryBot.create(:template_vmware)

      expect(region.vms_and_templates).to match_array [vm, t]
    end
  end

  describe "#remote_ws_url" do
    let(:hostname) { "www.manageiq.org" }

    context "with a recently active server" do
      let(:ip) { "1.1.1.94" }
      let(:url) { "https://www.manageiq.org" }
      let!(:web_server) do
        FactoryBot.create(:miq_server, :has_active_webservices => true,
                                       :hostname               => hostname,
                                       :ipaddress              => ip)
      end

      it "fetches the url from server" do
        expect(region.remote_ws_url).to eq("https://#{ip}")
      end

      it "fetches the url from the setting" do
        Vmdb::Settings.save!(web_server, :webservices => {:url => url})
        expect(region.remote_ws_url).to eq(url)
      end

      context "podified" do
        before do
          expect(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
          expect(ENV).to receive(:fetch).with("APPLICATION_DOMAIN", nil).and_return("manageiq.apps.mycluster.com")
        end

        it "returns the applicationDomain from the CR" do
          expect(region.remote_ws_url).to eq("https://manageiq.apps.mycluster.com")
        end
      end
    end

    it "with no recently active servers" do
      FactoryBot.create(:miq_server, :has_active_webservices => true, :hostname => hostname, :last_heartbeat => 11.minutes.ago.utc)

      expect(region.remote_ws_url).to be_nil
    end
  end

  describe "#remote_ui_url" do
    let(:hostname) { "www.manageiq.org" }

    context "with a recently active server" do
      let(:ip) { "1.1.1.94" }
      let(:url) { "http://localhost:3000" }
      let!(:ui_server) do
        FactoryBot.create(:miq_server, :has_active_userinterface => true,
                                       :hostname                 => hostname,
                                       :ipaddress                => ip)
      end

      it "fetches the url from server" do
        expect(region.remote_ui_url).to eq("https://#{hostname}")
      end

      it "fetches the url from the setting" do
        Vmdb::Settings.save!(ui_server, :ui => {:url => url})
        expect(region.remote_ui_url).to eq(url)
      end

      context "podified" do
        before do
          expect(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
          expect(ENV).to receive(:fetch).with("APPLICATION_DOMAIN", nil).and_return("manageiq.apps.mycluster.com")
        end

        it "returns the applicationDomain from the CR" do
          expect(region.remote_ui_url).to eq("https://manageiq.apps.mycluster.com")
        end
      end
    end

    it "with no recently active servers" do
      FactoryBot.create(:miq_server, :has_active_userinterface => true, :hostname => hostname, :last_heartbeat => 11.minutes.ago.utc)

      expect(region.remote_ws_url).to be_nil
    end
  end

  describe "#remote_ui_miq_server" do
    it "with no recently active servers" do
      server = FactoryBot.create(:miq_server, :has_active_userinterface => true, :hostname => "example.com")

      expect(region.remote_ui_miq_server).to eq(server)
    end

    it "with no recently active servers" do
      FactoryBot.create(:miq_server, :has_active_userinterface => true, :hostname => "example.com", :last_heartbeat => 1.month.ago.utc)

      expect(region.remote_ui_miq_server).to be_nil
    end
  end

  describe "#remote_ws_miq_server" do
    it "with no recently active servers" do
      server = FactoryBot.create(:miq_server, :has_active_webservices => true, :hostname => "example.com")

      expect(region.remote_ws_miq_server).to eq(server)
    end

    it "with no recently active servers" do
      FactoryBot.create(:miq_server, :has_active_webservices => true, :hostname => "example.com", :last_heartbeat => 1.month.ago.utc)

      expect(region.remote_ws_miq_server).to be_nil
    end
  end

  context ".destroy_region" do
    let!(:regionA)      { FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number + 1) }
    let!(:regionB)      { FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number + 2) }
    let!(:vm_regionA)   { FactoryBot.create(:vm_vmware, :id => ApplicationRecord.id_in_region(1, regionA.region)) }
    let!(:vm_regionB)   { FactoryBot.create(:vm_vmware, :id => ApplicationRecord.id_in_region(1, regionB.region)) }
    let!(:host_regionA) { FactoryBot.create(:host_vmware, :id => ApplicationRecord.id_in_region(1, regionA.region)) }
    let!(:host_regionB) { FactoryBot.create(:host_vmware, :id => ApplicationRecord.id_in_region(1, regionB.region)) }

    it "removes target region's rows" do
      described_class.destroy_region(ApplicationRecord.connection, regionB.region, %w[hosts vms])
      expect(Host.all.pluck(:id)).to match_array([vm_regionA.id])
      expect(Vm.all.pluck(:id)).to match_array([vm_regionA.id])
    end
  end
end
