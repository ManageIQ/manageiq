describe ManageIQ::Providers::PhysicalInfraManager do
  before :all do
    @auth = { :user => 'admin', :pass => 'smartvm', :host => 'localhost', :port => '3000' }
  end

  it 'will count physical servers' do
    ps = FactoryGirl.create(:physical_server)
    pim = FactoryGirl.create(:ems_physical_infra,
                             :name     => "LXCA",
                             :hostname => "0.0.0.0")

    pim.physical_servers = [ps]
    expect(pim.total_physical_servers).to be(1)
  end

  it 'will count hosts' do
    ps = FactoryGirl.create(:physical_server)
    host = FactoryGirl.create(:host)
    pim = FactoryGirl.create(:ems_physical_infra,
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
    pim = FactoryGirl.create(:ems_physical_infra,
                             :name     => "LXCA",
                             :hostname => "0.0.0.0")

    host.vms = [vm]
    ps.host = host
    pim.physical_servers = [ps]
    expect(pim.total_vms).to be(1)
  end

  it 'will check supports_console returns false' do
    ps = FactoryGirl.create(:ems_physical_infra,
                            :name     => "LXCA",
                            :hostname => "0.0.0.0")
    expect(ps.supports_console?).to be(false)
  end

  it 'will return false if console is not supported' do
    ps = FactoryGirl.create(:ems_physical_infra,
                            :name     => "LXCA",
                            :hostname => "0.0.0.0")
    expect(ps.console_supported?).to be(false)
  end

  it 'will raise  exception for cnosle url if  console is not supported' do
    ps = FactoryGirl.create(:ems_physical_infra,
                            :name     => "LXCA",
                            :hostname => "0.0.0.0")
    expect { ps.console_url }.to raise_error(MiqException::Error)
  end
end
