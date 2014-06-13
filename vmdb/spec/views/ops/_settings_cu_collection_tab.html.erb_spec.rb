require "spec_helper"

describe "ops/_settings_cu_collection_tab.html.erb" do
  before do
    assign(:sb, {:active_tab => "settings_cu_collection"})
  end

  it "Check All checkbox have unique id for Clusters trees" do
    #setting up simple data to show Check All checkbox on screen
    assign(:edit, {:new => {
      :all_clusters => false,
      :clusters => [{:name => "Some Cluster", :id => "Some Id" , :capture => true}]
    }})
    assign(:session, {:tree_name => "clhosts_tree"})
    #creating simple tree for the view to render
    assign(:temp, {:clhosts_tree => {"id"=>0, "item"=>{}}.to_json})
    render
    response.should have_selector("input#cl_toggle")
  end

  it "Check All checkbox have unique id for Storage trees" do
    #setting up simple data to show Check All checkbox on screen
    assign(:edit, {:new => {
      :all_storages => false,
      :storages => [{:name => "Some Storage", :id => "Some Id" , :capture => true}]
    }})
    assign(:session, {:ds_tree_name => "cu_datastore_tree"})
    #creating simple tree for the view to render
    assign(:temp, {:cu_datastore_tree => {"id"=>0, "item"=>{}}.to_json})
    render
    response.should have_selector("input#ds_toggle")
  end
end
