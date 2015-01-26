require_relative 'spec_helper'

describe ManageiqForeman::Connection do
  let(:connection) do
    described_class.new(:base_url => "example.com", :username => "admin", :password => "smartvm", :verify_ssl => nil)
  end

  describe "#host" do
    context "with 2 hosts" do
      let(:results) { connection.hosts("per_page" => 2) }

      it "fetches 2 hosts" do
        with_vcr do
          expect(results.size).to eq(2)
        end
      end

      it "has keys we need" do
        with_vcr do
          expect(results.first.keys).to include(*%w(id name ip mac hostgroup_id uuid build
                                                    enabled operatingsystem_id domain_id ptable_id medium_id))
        end
      end
    end
  end

  describe "#all" do
    context "with hosts" do
      let(:results) { connection.all(:hosts) }

      it "paginates" do
        with_vcr("_all") do
          expect(results.size).to eq(36)
        end
      end
    end
  end
end
