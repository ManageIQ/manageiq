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
    return false unless @edit || @filters
    category.entries.any? { |entry| selected_entry_value(category, entry) }
  end

  def selected_entry_value(category, entry)
    return false unless @edit || @filters
    path = "#{category.name}-#{entry.name}"
    (@edit && @edit.fetch_path(:new, :filters, path)) || (@filters && @filters.key?(path))
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix         => 'tags_',
                  :check_url         => "/ops/rbac_group_field_changed/#{@group.present? ? @group.id : "new"}___",
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
    return @categories.size if count_only
    # open node if at least one of his kids is selected
    if @edit.present? || @filters.present?
      @categories.each do |c|
        open_node("cl-#{to_cid(c.id)}") if contain_selected_kid(c)
      end
    end
    count_only_or_objects(count_only, @categories)
  end

  def x_get_classification_kids(parent, count_only)
    return parent.entries.size if count_only
    kids = parent.entries.map do |kid|
      select = selected_entry_value(parent, kid)
      {:id          => kid.id,
       :image       => 'tag',
       :text        => kid.description,
       :checkable   => @edit.present?,
       :tooltip     => _("Tag: %{description}") % {:description => kid.description},
       :cfmeNoClick => true,
       :select      => select}
    end
    count_only_or_objects(count_only, kids)
  end
end
