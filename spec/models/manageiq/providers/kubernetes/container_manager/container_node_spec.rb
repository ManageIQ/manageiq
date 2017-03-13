describe ContainerNode do
  it "has distinct routes" do
    service = FactoryGirl.create(
    :container_service,
    :name => "s",
    :container_routes => [FactoryGirl.create(:container_route, :name => "rt")]
    )
    expect(FactoryGirl.create(
    :container_node,
    :name => "n",
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_services => [service]),
                          FactoryGirl.create(:container_group, :name => "g2", :container_services => [service])]
    ).container_routes.count).to eq(1)
  end

  it "has distinct images" do
    node = FactoryGirl.create(:container_node, :name => "n")
    group = FactoryGirl.create(
      :container_group,
      :name           => "group",
      :container_node => node
    )
    group2 = FactoryGirl.create(
      :container_group,
      :name           => "group2",
      :container_node => node
    )
    FactoryGirl.create(
      :container_image,
      :containers => [FactoryGirl.create(:container, :name => "container_a", :container_group => group),
                      FactoryGirl.create(:container, :name => "container_b", :container_group => group2)]
    )
    expect(node.container_images.count).to eq(1)
  end

  describe "#external_logging_path" do
    def get_query(path)
      index = ".operations.*"
      prefix_len = (ContainerNode::EXTERNAL_LOGGING_PATH % {:index => index, :query => 'MARKER'}).index('MARKER')
      path[prefix_len..(prefix_len + path[prefix_len..-1].index("index:'.operations.*'") - 4)]
    end

    it "will query for nothing when no name/fqdn is available" do
      node = FactoryGirl.create(:container_node, :name => "")
      query = get_query(node.external_logging_path)
      expect(query).to eq("bool:(filter:(or:!((term:(hostname:'')))))")
    end

    it "queries both fqdn and hostname when both are avaialble only from kubernetes lables" do
      node = FactoryGirl.create(:container_node, :name => "other_name")
      node.labels.create(:name => "kubernetes.io/hostname", :value => "hello.world.com")
      query = get_query(node.external_logging_path)
      expect(query).to eq("bool:(filter:(or:!((term:(hostname:'hello.world.com')),(term:(hostname:'hello')))))")
    end

    it "queries both fqdn and hostname when both are avaialble" do
      node = FactoryGirl.create(:container_node, :name => "hello.world.com")
      query = get_query(node.external_logging_path)
      expect(query).to eq("bool:(filter:(or:!((term:(hostname:'hello.world.com')),(term:(hostname:'hello')))))")
    end

    it "queries only for the name/fqdn when hostname can't be parsed" do
      node = FactoryGirl.create(:container_node, :name => "hello")
      query = get_query(node.external_logging_path)
      expect(query).to eq("bool:(filter:(or:!((term:(hostname:'hello')))))")
    end
  end
end
