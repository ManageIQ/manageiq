describe ManageIQ::Providers::Elasticsearch::DatawarehouseManager::Refresher do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    @ems = FactoryGirl.create(:ems_elasticsearch_datawarehouse,
                              :hostname => "elastic-hostname")
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:elasticsearch_datawarehouse)
  end

  it "will perform a full refresh on openshift" do
    2.times do
      @ems.reload
      VCR.use_cassette(described_class.name.underscore,
                       # :match_requests_on => [:path,], :record => :new_episodes) do
                       :match_requests_on => [:path,]) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_ems
      assert_table_counts
      assert_specific_container_node
      assert_specific_cluster_attributes
    end
  end

  def assert_table_counts
    expect(DatawarehouseNode.count).to eq(1)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :port => 443,
      :type => "ManageIQ::Providers::Elasticsearch::DatawarehouseManager"
    )
  end

  def assert_specific_container_node
    @dhnode = DatawarehouseNode.first
    expect(@dhnode).to have_attributes(
      :name   => "Entropic Man",
      :master => true
    )

    expect(@dhnode.ext_management_system).to eq(@ems)
  end

  def assert_specific_cluster_attributes
    @ca = @ems.cluster_attributes.all
    expect(@ca.find_by(:name => "health-active_shards").value).to eq("20")
  end
end
