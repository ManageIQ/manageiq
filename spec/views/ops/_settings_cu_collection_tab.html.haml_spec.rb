describe "ops/_settings_cu_collection_tab.html.haml" do
  before do
    assign(:sb, :active_tab => "settings_cu_collection")

    @host = FactoryGirl.create(:host, :name => 'Host Name')
    FactoryGirl.create(:storage, :name => 'Name', :id => 1, :hosts => [@host])
    @datastore = [{:id       => 1,
                   :name     => 'Datastore',
                   :location => 'Location',
                   :capture  => false}]
    @datastore_tree = TreeBuilderDatastores.new(:datastore, :datastore_tree, {}, true, @datastore)

    @ho_enabled = [FactoryGirl.create(:host)]
    @ho_disabled = [FactoryGirl.create(:host)]
    allow(EmsCluster).to receive(:get_perf_collection_object_list).and_return(:'1'.to_i =>
                                                                                {:id          => 1,
                                                                                 :name        => 'Name',
                                                                                 :capture     => 'unsure',
                                                                                 :ho_enabled  => @ho_enabled,
                                                                                 :ho_disabled => @ho_disabled})
    @non_cluster_hosts = [{:id => 2, :name => 'Non Cluster Host', :capture => true}]
    @cluster = {:clusters => [{:id => 1, :name => 'Name', :capture => 'unsure'}], :non_cl_hosts => @non_cluster_hosts}
    @cluster_tree = TreeBuilderClusters.new(:cluster, :cluster_tree, {}, true, @cluster)
  end

  it "Check All checkbox have unique id for Clusters trees" do
    # setting up simple data to show Check All checkbox on screen
    assign(:edit, :new => {
             :all_clusters => false,
             :clusters     => [{:name => "Some Cluster", :id => "Some Id", :capture => true}]
           })
    render
    expect(response).to have_selector("input#cl_toggle")
  end

  it "Check All checkbox have unique id for Storage trees" do
    # setting up simple data to show Check All checkbox on screen
    assign(:edit, :new => {
             :all_storages => false,
             :storages     => [{:name => "Some Storage", :id => "Some Id", :capture => true}]
           })
    render
    expect(response).to have_selector("input#ds_toggle")
  end
end
