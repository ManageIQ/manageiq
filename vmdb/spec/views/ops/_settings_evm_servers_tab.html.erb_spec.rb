require "spec_helper"

describe "ops/_settings_evm_servers_tab.html.erb" do
  before do
    assign(:sb, {:active_tab => "settings_evm_servers"})
    assign(:selected_zone, FactoryGirl.create(:zone))
    assign(:servers, [])
  end

  it "VDI Farms should only be displayed if VDI flag is set" do
    cfg = {:product => {:vdi => false}}
    view.stub(:get_vmdb_config).and_return(cfg)
    render
    response.should_not have_selector('td', :text => 'VDI Farms')
  end
end
