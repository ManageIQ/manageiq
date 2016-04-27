describe TreeBuilderServiceCatalog do
  include CompressedIds
  before do
    Tenant.seed
    @catalog = FactoryGirl.create(:service_template_catalog, :name => "My Catalog")
    FactoryGirl.create(:service_template,
                       :name                     => "Display in Catalog",
                       :service_template_catalog => @catalog,
                       :display                  => true)
    FactoryGirl.create(:service_template,
                       :name                     => "Do not Display in Catalog",
                       :service_template_catalog => @catalog,
                       :display                  => false)
    @tree = TreeBuilderServiceCatalog.new(:svccat_tree, "svccat", {})
  end

  it "#x_get_tree_roots" do
    roots = @tree.send(:x_get_tree_roots, false, {})
    expect(roots.first.name).to eq(@catalog.name)
  end

  it "#x_get_tree_stc_kids returns items that are set to be displayed in catalog" do
    items = @tree.send(:x_get_tree_stc_kids, @catalog, false)
    expect(items.size).to eq(1)
    expect(items.first.name).to eq("Display in Catalog")
  end
end
