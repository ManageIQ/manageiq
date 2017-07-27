require 'xclarity_client'

describe ManageIQ::Providers::PhysicalInfraManager do
  before :all do
    @auth = { :user => 'admin', :pass => 'smartvm', :host => 'localhost', :port => '3000' }
  end

  it 'will count physical servers' do
    ps = FactoryGirl.create(:physical_server)
    pim = FactoryGirl.create(:generic_physical_infra,
                             :name     => "LXCA",
                             :hostname => "0.0.0.0")

    pim.physical_servers = [ps]
    expect(pim.total_physical_servers).to be(1)
  end

  it 'will count hosts' do
    ps = FactoryGirl.create(:physical_server)
    host = FactoryGirl.create(:host)
    pim = FactoryGirl.create(:generic_physical_infra,
                             :name     => "LXCA",
                             :hostname => "0.0.0.0")

    ps.host = host
    pim.physical_servers = [ps]
    expect(pim.total_hosts).to be(1)
  end

  it 'will count vms' do
    ps = FactoryGirl.create(:physical_server)
    host = FactoryGirl.create(:host)
    vm = FactoryGirl.create(:vm)
    pim = FactoryGirl.create(:generic_physical_infra,
                             :name     => "LXCA",
                             :hostname => "0.0.0.0")

    host.vms = [vm]
    ps.host = host
    pim.physical_servers = [ps]
    expect(pim.total_vms).to be(1)
  end
end
