require 'spec_helper'

describe EmsRefresh::SaveInventoryInfra do
  let(:refresher) do
    Class.new do
      include EmsRefresh::SaveInventoryInfra

      def _log
        @logger ||= Vmdb.null_logger
      end
    end.new
  end

  context ".find_host" do
    it "with ems_ref" do
      FactoryGirl.create(:host, :ems_ref => "some_ems_ref")

      expect(refresher.find_host({:ems_ref => "some_ems_ref"}, nil)).to be_kind_of(Host)
    end

    it "with ems_ref and ems_id" do
      FactoryGirl.create(:host, :ems_ref => "some_ems_ref")
      host_with_ems_id = FactoryGirl.create(:host, :ems_ref => "some_ems_ref_2", :ems_id => 1)

      expect(refresher.find_host({:ems_ref => "some_ems_ref_2", :name => "name"}, nil)).to be_nil
      expect(refresher.find_host({:ems_ref => "some_ems_ref_2", :name => "name"}, 1)).to   eq(host_with_ems_id)
    end

    it "with hostname and ipaddress" do
      FactoryGirl.create(:host, :ems_ref => "some_ems_ref", :hostname => "my.hostname", :ipaddress => "192.168.1.1")
      expected_host = FactoryGirl.create(:host, :ems_ref => "some_ems_ref", :hostname => "my.hostname", :ipaddress => "192.168.1.2")

      expect(refresher.find_host(expected_host.slice(:hostname, :ipaddress), nil)).to eq(expected_host)
    end
  end

    context ".look_up_host" do
    let(:host_3_part_hostname)    { FactoryGirl.create(:host_vmware, :hostname => "test1.example.com",       :ipaddress => "192.168.1.1") }
    let(:host_4_part_hostname)    { FactoryGirl.create(:host_vmware, :hostname => "test2.dummy.example.com", :ipaddress => "192.168.1.2") }
    let(:host_duplicate_hostname) { FactoryGirl.create(:host_vmware, :hostname => "test2.example.com",       :ipaddress => "192.168.1.3", :ems_ref => "host-1", :ems_id => 1) }
    let(:host_no_ems_id)          { FactoryGirl.create(:host_vmware, :hostname => "test2.example.com",       :ipaddress => "192.168.1.4", :ems_ref => "host-2") }
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

    it "with fqdn, ipaddress, and different ems_ref returns nil" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => "dummy_ref")).to be_nil
    end

    it "with ems_ref and ems_id" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref, :ems_id => 1)).to eq(host_duplicate_hostname)
    end

    it "with ems_ref and other ems_id" do
      expect(refresher.look_up_host(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref, :ems_id => 0)).to be_nil
    end
  end
end
