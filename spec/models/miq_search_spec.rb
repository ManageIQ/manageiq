require "spec_helper"

describe MiqSearch do
  describe '#descriptions' do
    it "hashes" do
      srchs = [
        FactoryGirl.create(:miq_search, :description => 'a'),
        FactoryGirl.create(:miq_search, :description => 'b'),
        FactoryGirl.create(:miq_search, :description => 'c')
      ]

      expect(MiqSearch.descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description,
        srchs[2].id.to_s => srchs[2].description)
    end

    it "supports scopes" do
      srchs = [
        FactoryGirl.create(:miq_search, :description => 'a', :db => 'Vm'),
        FactoryGirl.create(:miq_search, :description => 'b', :db => 'Vm'),
        FactoryGirl.create(:miq_search, :description => 'c', :db => 'Host')
      ]

      expect(MiqSearch.where(:db => 'Vm').descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description)
    end
  end
end
