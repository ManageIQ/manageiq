class TreeBuilderTags < TreeBuilder
  has_kids_for Classification, [:x_get_classification_kids]

  def initialize(name, type, sandbox, build, params)
    @edit = params[:edit]
    @filters = params[:filters]
    @group = params[:group]
    @categories = Classification.categories.find_all do |c|
      c if c.show || !%w(folder_path_blue folder_path_yellow).include?(c.name)
    end
    @categories.sort_by! { |c| c.description.downcase }
    super(name, type, sandbox, build)
    @tree_state.x_tree(name)[:open_nodes] = []
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :add_root => false,
     :lazy     => false}
  end

  def contain_selected_kid(category)
    category.entries.any? do |entry|
      path = "#{category.name}-#{entry.name}"
      (@edit && @edit[:new][:filters].key?(path)) || (@filters && @filters.key?(path))
    end
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix         => 'tags_',
                  :check_url         => "/ops/rbac_group_field_changed/#{@group.id || "new"}___",
                  :oncheck           => @edit.nil? ? nil : "miqOnCheckUserFilters",
                  :checkboxes        => true,
                  :highlight_changes => true,
                  :cfmeNoClick       => true,
                  :onclick           => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only, _options)
    # open node if at least one of his kids is selected
    @categories.each do |c|
      open_node("cl-#{to_cid(c.id)}") if contain_selected_kid(c)
    end
    count_only_or_objects(count_only, @categories)
  end

  def x_get_classification_kids(parent, count_only)
    kids = parent.entries.map do |kid|
      kid_id = "#{parent.name}-#{kid.name}"
      select = (@edit && @edit.fetch_path(:new, :filters, kid_id)) || (@filters && @filters.key?(kid_id))
      {:id          => kid.id,
       :image       => '100/tag.png',
       :text        => kid.description,
       :checkable   => @edit.present?,
       :tooltip     => _("Tag: %{description}") % {:description => kid.description},
       :cfmeNoClick => true,
       :select      => select}
    end
    count_only_or_objects(count_only, kids)
  end
end
