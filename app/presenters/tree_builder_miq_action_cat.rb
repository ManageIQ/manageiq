class TreeBuilderMiqActionCat < TreeBuilder
  has_kids_for Classification, [:x_get_tree_classification_kids]

  private

  # Maybe we should define NodeBuilder inside this class?
  def node_builder
    TreeNodeBuilderMiqActionCat
  end

  def initialize(name, type, sandbox, build = true, tenant_name)
    @tenant_name = tenant_name
    super(name, type, sandbox, build)
  end

  def tree_init_options(_tree_name)
  {:expand        => true,
   :lazy          => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix   => "cat_tree",
                  :click_url => "/miq_policy/action_tag_pressed/",
                  :onclick   => "miqOnClickTagCat")
  end

  def root_options
    title = @tenant_name
    [title, title, "tag.png"]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_count_only, _options)
    cats = Classification.categories.select(&:show).sort_by(&:name)
    cats = cats.select{|c| c.entries.any? }
    cats.sort_by! { |c| c.description.downcase }
    count_only_or_objects(_count_only, cats)
  end

  def x_get_tree_classification_kids(c, count_only)
    ent = c.entries
    c_kids = ent.sort_by { |t| t.description.downcase }
    count_only_or_objects(count_only, c_kids)
  end
end