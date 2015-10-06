require "spec_helper"

describe "ops/_settings_evm_servers_tab.html.haml" do
  before do
    assign(:sb, :active_tab => "settings_evm_servers")
    @selected_zone = FactoryGirl.create(:zone, :name => 'One Zone', :description => " One Description", :settings =>
                                                {:proxy_server_ip => '1.2.3.4', :concurrent_vm_scans => 0, :ntp => {:server => ['Server 1']}})
    @servers = []
  end

  context "zone selected" do
    it "should  show basic zone information" do
      render :partial => "ops/settings_evm_servers_tab"
      expect(response.body).to include('Name')
      expect(response.body).to include('Description')
      expect(response.body).to include('SmartProxy Server IP')
      expect(response.body).to include('NTP Servers')
      expect(response.body).to include('Max active VM Scans')
    end
  end
end
