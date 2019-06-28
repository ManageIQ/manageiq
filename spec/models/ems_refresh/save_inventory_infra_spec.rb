describe EmsRefresh::SaveInventoryInfra do
  let(:ems) { FactoryBot.create(:ems_infra) }
  let(:refresher) do
    Class.new do
      include EmsRefresh::SaveInventoryInfra

      def _log
        @logger ||= Vmdb.logger
      end
    end.new
  end

  context ".find_host" do
    let(:hosts_by_name) { ems.hosts.group_by { |h| h.name.downcase }.except(nil) }
    let(:hosts_by_hostname) { ems.hosts.group_by { |h| h.hostname.downcase }.except(nil) }
    let(:hosts_by_ipaddress) { ems.hosts.group_by { |h| h.ipaddress }.except(nil) }

    it "with hostname and ipaddress" do
      FactoryBot.create(:host, :ems_ref => "some_ems_ref", :hostname => "my.hostname", :ipaddress => "192.168.1.1", :ext_management_system => ems)
      expected_host = FactoryBot.create(:host, :ems_ref => "some_ems_ref", :hostname => "my.hostname", :ipaddress => "192.168.1.2", :ext_management_system => ems)

      expect(refresher.find_host(expected_host.slice(:hostname, :ipaddress), ems.id, hosts_by_name, hosts_by_hostname, hosts_by_ipaddress)).to eq(expected_host)
    end

    it "with name" do
      FactoryBot.create(:host, :ext_management_system => ems)
      expected_host = FactoryBot.create(:host, :ext_management_system => ems)
      expect(refresher.find_host(expected_host.slice(:name), ems, hosts_by_name, {}, {}))
    end
  end

  context ".look_up_host" do
    let(:host_3_part_hostname)    { FactoryBot.create(:host_vmware, :hostname => "test1.example.com",       :ipaddress => "192.168.1.1") }
    let(:host_4_part_hostname)    { FactoryBot.create(:host_vmware, :hostname => "test2.dummy.example.com", :ipaddress => "192.168.1.2") }
    let(:host_duplicate_hostname) { FactoryBot.create(:host_vmware, :hostname => "test2.example.com",       :ipaddress => "192.168.1.3", :ems_ref => "host-1", :ems_id => 1) }
    let(:host_no_ems_id)          { FactoryBot.create(:host_vmware, :hostname => "test2.example.com",       :ipaddress => "192.168.1.4", :ems_ref => "host-2") }
    before do
      host_3_part_hostname
      host_4_part_hostname
      host_duplicate_hostname
      host_no_ems_id
    end

    it "with exact hostname and IP" do
      expect(refresher.look_up_host(host_3_part_hostname.hostname, host_3_part_hostname.ipaddress)).to eq(host_3_part_hostname)
      expect(refresher.look_up_host(host_4_part_hostname.hostname, host_4_part_hostname.ipaddress)).to eq(host_4_part_hostname)
    end

    it "with exact hostname and updated IP" do
      expect(refresher.look_up_host(host_3_part_hostname.hostname, "192.168.1.254")).to eq(host_3_part_hostname)
      expect(refresher.look_up_host(host_4_part_hostname.hostname, "192.168.1.254")).to eq(host_4_part_hostname)
    end

    it "with exact IP and updated hostname" do
      expect(refresher.look_up_host("not_it.example.com", host_3_part_hostname.ipaddress)).to       eq(host_3_part_hostname)
      expect(refresher.look_up_host("not_it.dummy.example.com", host_4_part_hostname.ipaddress)).to eq(host_4_part_hostname)
    end

    it "with exact IP only" do
      expect(refresher.look_up_host(nil, host_3_part_hostname.ipaddress)).to eq(host_3_part_hostname)
      expect(refresher.look_up_host(nil, host_4_part_hostname.ipaddress)).to eq(host_4_part_hostname)
    end

    it "with exact hostname only" do
      expect(refresher.look_up_host(host_3_part_hostname.hostname, nil)).to eq(host_3_part_hostname)
      expect(refresher.look_up_host(host_4_part_hostname.hostname, nil)).to eq(host_4_part_hostname)
    end

    it "with bad fqdn hostname only" do
      expect(refresher.look_up_host("test1.example.org", nil)).to           be_nil
      expect(refresher.look_up_host("test2.something.example.com", nil)).to be_nil
    end

    it "with bad partial hostname only" do
      expect(refresher.look_up_host("test", nil)).to            be_nil
      expect(refresher.look_up_host("test2.something", nil)).to be_nil
    end

    it "with partial hostname only" do
      expect(refresher.look_up_host("test1", nil)).to       eq(host_3_part_hostname)
      expect(refresher.look_up_host("test2.dummy", nil)).to eq(host_4_part_hostname)
    end

    it "with duplicate hostname and ipaddress" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress)).to eq(host_duplicate_hostname)
    end

    it "with fqdn, ipaddress, and ems_ref finds right host" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref)).to eq(host_duplicate_hostname)
    end

    it "with fqdn, ipaddress, and ems_ref finds right host without an ems_id (reconnect orphaned host)" do
      expect(refresher.look_up_host(host_no_ems_id.hostname, host_no_ems_id.ipaddress, :ems_ref => host_no_ems_id.ems_ref)).to eq(host_no_ems_id)
    end

    it "with ems_ref and ems_id" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref, :ems_id => 1)).to eq(host_duplicate_hostname)
    end

    it "with ems_ref and other ems_id" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref, :ems_id => 0)).to be_nil
    end
  end

  context ".save_hosts_inventory" do
    context "with an archived host" do
      # NOTE: I had to provide a non-127.0.0.1 ip address which is what is default
      # from the factory because find_host skips these
      let(:host) { FactoryBot.create(:host_with_ref, :ipaddress => "10.10.10.10") }

      it "should reconnect a disconnected host" do
        data = {
          :name      => host.name,
          :hostname  => host.hostname,
          :ipaddress => host.ipaddress,
          :ems_ref   => "new_ems_ref"
        }

        EmsRefresh.save_hosts_inventory(ems, [data])

        host.reload
        expect(host.ext_management_system).to eq(ems)
        expect(host.ems_ref).to eq("new_ems_ref")
      end
    end

    it "should handle >10 hosts with duplicate hostnames" do
      data = Array.new(11) do |i|
        {
          :name     => 'localhost',
          :hostname => 'localhost',
          :ems_ref  => "host-#{i}"
        }
      end

      EmsRefresh.save_hosts_inventory(ems, data)

      expect(ems.hosts.length).to eq(data.length)
    end
  end
end
