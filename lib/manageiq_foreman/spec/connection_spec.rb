require_relative 'spec_helper'

describe ManageiqForeman::Connection do
  let(:connection) do
    described_class.new(:base_url => "example.com", :username => "admin", :password => "smartvm", :verify_ssl => nil)
  end

  describe "#host" do
    context "with 2 hosts" do
      let(:results) { connection.hosts("per_page" => 2) }

      it "fetches 2 hosts" do
        with_vcr("_2_hosts") do
          expect(results.size).to eq(2)
          expect(results.total).to eq(39)
        end
      end

      it "has keys we need" do
        with_vcr("_2_hosts") do
          expect(results.first.keys).to include(*%w(id name ip mac hostgroup_id uuid build
                                                    enabled operatingsystem_id domain_id ptable_id medium_id))
        end
      end
    end
  end

  describe "#operating_system_detail" do
    context "with 2 operating_system_details" do
      let(:results) { connection.operating_system_details("per_page" => 2) }

      it "fetches 2 operating_system_details" do
        with_vcr("_2_operating_systems") do
          expect(results.size).to eq(2)
        end
      end
    end
  end

  describe "#denormalized_hostgroups" do
    # can't denormalize hostgroups with partial lists
    context "with all hostgroups" do
      let(:orig)         { connection.hostgroups }
      let(:orig_child)   { orig.detect { |r| r["name"] == 'ProviderRefreshSpec-ChildHostGroup' } }
      let(:parent)       { results.detect { |r| r["name"] == 'ProviderRefreshSpec-HostGroup' } }
      let(:results)      { connection.denormalized_hostgroups }
      let(:merge_child)  { results.detect { |r| r["name"] == 'ProviderRefreshSpec-ChildHostGroup' } }

      it "links hostgroups" do
        with_vcr("_hostgroups") do
          expect(orig.size).to eq(results.size)
        end
        assert_parent_attr
        assert_orig_child
        assert_merge_child
      end

      def assert_parent_attr
        expect(parent["operatingsystem_id"]).to eq(4)
        expect(parent["medium_id"]).to eq(8)
        expect(parent["ptable_id"]).to be_nil
      end

      def assert_orig_child
        expect(orig_child["operatingsystem_id"]).to be_nil
        expect(orig_child["medium_id"]).to be_nil
        expect(orig_child["ptable_id"]).to eq(12)
      end

      def assert_merge_child
        expect(merge_child["operatingsystem_id"]).to eq(4)
        expect(merge_child["medium_id"]).to eq(8)
        expect(merge_child["ptable_id"]).to eq(12)
      end
    end
  end

  describe "simple accessor methods" do
    it "works" do
      with_vcr("_all_methods") do
        expect(connection.hosts(:per_page => 2).size).to eq(2)
        expect(connection.hostgroups(:per_page => 2).size).to eq(2)
        expect(connection.operating_systems(:per_page => 2).size).to eq(2)
        expect(connection.media(:per_page => 2).size).to eq(2)
        expect(connection.ptables(:per_page => 2).size).to eq(2)
        expect(connection.config_templates(:per_page => 2).size).to eq(2)
        expect(connection.subnets(:per_page => 2).size).to eq(2)
      end
    end
  end

  describe "#all" do
    context "with hosts" do
      let(:results) { connection.all(:hosts, :per_page => 10) }

      it "paginates" do
        with_vcr("_all") do
          expect(results.size).to eq(39)
        end
      end
    end
  end
end
