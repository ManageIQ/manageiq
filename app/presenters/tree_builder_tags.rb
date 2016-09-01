class TreeBuilderTags < TreeBuilder
  has_kids_for Classification, [:x_get_classification_kids]
  #TODO delete?
  def initialize(name, type, sandbox, build, edit, filters, group)
    @edit = edit
    @filters = filters
    @group = group
    @categories = Classification.categories.collect { |c| c unless !c.show || ["folder_path_blue", "folder_path_yellow"].include?(c.name) }.compact
    @categories.sort_by! { |c| c.description.downcase }
    super(name, type, sandbox, true)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :add_root => false,
     :lazy     => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix      => 'myco_',
                  :check_url      => "ops/rbac_group_field_changed/#{@group.id || "new"}___",
                  :oncheck        => @edit.nil? ? nil : "miqOnCheckUserFilters",
                  :disable_checks => @edit.nil?,
                  :checkboxes     => true,
                  :onclick        => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    count_only_or_objects(count_only, @categories)
  end

  def x_get_classification_kids(parent, count_only)
    kids = parent.entries.map do |kid|
      kid_id = "#{parent.name}_#{kid.name}"
      kid_class = if (@edit && @edit[:new][:filters][kid_id] == @edit[:current][:filters][kid_id]) || ![kid_id].include?(@filters) # Check new vs current
                    "cfme-no-cursor-node"       # No cursor pointer
                  else
                    "cfme-blue-node"            # Show node as different
                  end
      parent[:expand] = true if (@edit && @edit[:new][:filters].key?(kid_id)) || (@filters && @filters.key?(kid_id))

      {:id       => kid_id,
       :image    => 'tag',
       :text     => kid.description,
       :tooltip  => _("Tag: %{description}") % {:description => kid.description},
       :select   => (@edit && @edit[:new][:filters].key?(kid_id)) || (@filters && @filters.key?(kid_id)),
       :addClass => kid_class,
       :children => []}
    end
    count_only_or_objects(count_only, kids)
  end
end