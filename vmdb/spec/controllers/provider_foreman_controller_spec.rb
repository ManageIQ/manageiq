require "spec_helper"

describe ProviderForemanController do
  render_views
  before(:each) do
    set_user_privileges
    @zone = FactoryGirl.create(:zone, :name => 'zone1')
    @provider = ProviderForeman.create(:name => "test", :url => "10.8.96.102", :verify_ssl => nil, :zone => @zone)
    sb = {}
    temp = {}
    sb[:active_tree] = :foreman_providers_tree
    controller.instance_variable_set(:@sb, sb)
    controller.instance_variable_set(:@temp, temp)
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    response.should redirect_to(:action => 'explorer')
  end

  it "renders explorer" do
    get :explorer
    expect(response.status).to eq(200)
  end

  it "renders show_list" do
    get :show_list
    expect(response.status).to eq(302 )
    expect(response.body).to_not be_empty
  end

  context "renders right cell text" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      controller.stub(:process_show_list)
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    end
    it "renders right cell text for root node" do
      temp = controller.instance_variable_get(:@temp)
      controller.send(:get_node_info, JSON.parse(temp[:foreman_providers_tree])[0]["key"])
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("All Foreman Providers")
    end

    it "renders right cell text for ConfigurationManagerForeman node" do
      temp = controller.instance_variable_get(:@temp)
      controller.send(:x_node_set, JSON.parse(temp[:foreman_providers_tree])[0]["children"][0]["key"], :foreman_providers_tree)
      controller.send(:get_node_info, JSON.parse(temp[:foreman_providers_tree])[0]["children"][0]["key"].to_s)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("Provider \"test Configuration Manager\"")
    end
  end

  it "builds foreman tree" do
    controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    temp = controller.instance_variable_get(:@temp)
    expect(JSON.parse(temp[:foreman_providers_tree])[0]["children"][0]["title"]).to eq("test Configuration Manager")
  end
end
