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
end
