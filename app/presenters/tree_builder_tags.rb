class TreeBuilderTags < TreeBuilder
  has_kids_for Classification, [:x_get_classification_kids]

  def initialize(name, type, sandbox, build, edit, filters, group)
    @edit = edit
    @filters = filters
    @group = group
    @categories = Classification.categories.collect { |c| c unless !c.show || ["folder_path_blue", "folder_path_yellow"].include?(c.name) }.compact
    @categories.sort_by! { |c| c.description.downcase }
    super(name, type, sandbox, true)
    @tree_state.x_tree(name)[:open_nodes] = []
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :add_root => false,
     :lazy     => false}
  end

  def has_selected_kid(category)
    open = false
      category.entries.each do |entry|
        kid_id = "#{category.name}-#{entry.name}"
        open = true if (@edit && @edit[:new][:filters].key?(kid_id)) || (@filters && @filters.key?(kid_id))
      end
    open
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix      => 'myco_',
                  :check_url      => "ops/rbac_group_field_changed/#{@group.id || "new"}___",
                  :oncheck        => @edit.nil? ? nil : "miqOnCheckUserFilters",
                  :checkboxes     => true,
                  :onclick        => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    @categories.each do |c|
      open_node("cl-#{to_cid(c.id)}") if has_selected_kid(c)
    end
    count_only_or_objects(count_only, @categories)
  end

  def x_get_classification_kids(parent, count_only)
    kids = parent.entries.map do |kid|
      kid_id = "#{parent.name}-#{kid.name}"
      kid_class = if (@edit && @edit[:new][:filters][kid_id] == @edit[:current][:filters][kid_id]) || ![kid_id].include?(@filters) # Check new vs current
                    "cfme-no-cursor-node"       # No cursor pointer
                  else
                    "cfme-blue-node"            # Show node as different
                  end
      select = false
          if (@edit && @edit[:new][:filters].key?(kid_id)) || (@filters && @filters.key?(kid_id))
            select = true
          end
      {:id       => kid.id,
       :image    => 'tag',
       :text     => kid.description,
       :tooltip  => _("Tag: %{description}") % {:description => kid.description},
       :select   => select,
       :cfmeNoClick  => true,
       :addClass => kid_class}
    end
    count_only_or_objects(count_only, kids)
  end
end