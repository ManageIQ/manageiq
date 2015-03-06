require_relative 'spec_helper'

describe ManageiqForeman::Connection do
  let(:connection) do
    described_class.new(:base_url => "example.com", :username => "admin", :password => "smartvm", :verify_ssl => nil)
  end

  describe "#fetch" do
    context "with 2 hosts" do
      let(:results) { connection.fetch(:hosts, "per_page" => 2) }

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
    context "with 2 operating_system details" do
      let(:results) { connection.all_with_details(:operating_systems, "per_page" => 2) }

      it "fetches 2 operating_system details" do
        with_vcr("_2_operating_systems") do
          expect(results.size).to eq(2)
        end
      end
    end
  end

  describe "simple accessor methods" do
    it "works" do
      with_vcr("_all_methods") do
        expect(connection.fetch(:hosts, :per_page => 2).size).to eq(2)
        expect(connection.fetch(:hostgroups, :per_page => 2).size).to eq(2)
        expect(connection.fetch(:operating_systems, :per_page => 2).size).to eq(2)
        expect(connection.fetch(:media, :per_page => 2).size).to eq(2)
        expect(connection.fetch(:ptables, :per_page => 2).size).to eq(2)
        expect(connection.fetch(:config_templates, :per_page => 2).size).to eq(2)
        expect(connection.fetch(:subnets, :per_page => 2).size).to eq(2)
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

  it "#inventory" do
    inventory = connection.inventory
    expect(inventory).to            be_instance_of(ManageiqForeman::Inventory)
    expect(inventory.connection).to eq(connection)
  end
end
