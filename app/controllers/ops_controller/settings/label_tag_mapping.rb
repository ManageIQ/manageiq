module OpsController::Settings::LabelTagMapping
  extend ActiveSupport::Concern

  def label_tag_mapping_edit
    case params[:button]
    when "cancel"
      @lt_map = session[:edit][:lt_map] if session[:edit] && session[:edit][:lt_map]
      if !@lt_map || @lt_map.id.blank?
        add_flash(_("Add of new %{model} was cancelled by the user") %
                    {:model => ui_lookup(:model => "ContainerLabelTagMapping")})
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") %
                    {:model => ui_lookup(:model => "ContainerLabelTagMapping"), :name => @lt_map.label_name})
      end
      get_node_info(x_node)
      @lt_map = @edit = session[:edit] = nil # clean out the saved info
      replace_right_cell(:nodetype => @nodetype)
    when "save", "add"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("label_tag_mapping_edit__#{id}", "replace_cell__explorer")
      @lt_map = @edit[:lt_map] if @edit && @edit[:lt_map]
      if @edit[:new][:label_name].blank?
        add_flash(_("Label is required"), :error)
      end
      if @edit[:new][:category].blank?
        add_flash(_("Category is required"), :error)
      end
      unless @flash_array.nil?
        javascript_flash
        return
      end
      if params[:button] == "add"
        label_tag_mapping_add(@edit[:new][:entity], @edit[:new][:label_name], @edit[:new][:category])
      else # save
        label_tag_mapping_update(@lt_map.id, @edit[:new][:category])
      end
    when "reset", nil # Reset or first time in
      if params[:id]
        @lt_map = ContainerLabelTagMapping.find(params[:id])
        lt_map_set_form_vars
      else
        lt_map_set_new_form_vars
      end
      @in_a_form = true
      session[:changed] = false
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell(:nodetype => "ltme")
    end
  end

  def entity_ui_name_or_all(entity)
    if entity.nil?
      _("<All>")
    else
      ui_lookup(:model => entity)
    end
  end

  def label_tag_mapping_get_all
    # Current UI only supports any-value -> category mappings
    mapping = ContainerLabelTagMapping.in_my_region.where(:label_value => nil)
    @lt_mapping = []
    mapping.each do |m|
      lt_map = {}
      lt_map[:id] = m.id
      lt_map[:entity] = entity_ui_name_or_all(m.labeled_resource_type)
      lt_map[:label_name] = m.label_name
      lt_map[:category] = m.tag.category.description
      @lt_mapping.push(lt_map)
    end
  end

  # Set form variables for mapping edit (initially or after reset)
  def lt_map_set_form_vars
    @edit = {}
    @edit[:lt_map] = @lt_map
    @edit[:new] = {}
    @edit[:key] = "label_tag_mapping_edit__#{@lt_map.id || "new"}"
    @edit[:new][:entity] = @lt_map.labeled_resource_type.nil? ? "<All>" : @lt_map.labeled_resource_type
    @edit[:new][:label_name] = @lt_map.label_name
    @edit[:new][:category] = @lt_map.tag.category.description
    @edit[:current] = copy_hash(@edit[:new])
    @edit[:new][:options] = ContainerLabelTagMapping::MAPPABLE_ENTITIES.collect do |name|
      [entity_ui_name_or_all(name), name]
    end
    session[:edit] = @edit
  end

  # Set form variables for mapping add
  def lt_map_set_new_form_vars
    @edit = {}
    # no :lt_map
    @edit[:new] = {}
    @edit[:key] = "label_tag_mapping_edit__new"
    @edit[:new][:entity] = nil
    @edit[:new][:label_name] = nil
    @edit[:new][:category] = nil
    @edit[:current] = copy_hash(@edit[:new])
    @edit[:new][:options] = ContainerLabelTagMapping::MAPPABLE_ENTITIES.collect do |name|
      [entity_ui_name_or_all(name), name]
    end
    session[:edit] = @edit
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def label_tag_mapping_field_changed
    return unless load_edit("label_tag_mapping_edit__#{params[:id]}", "replace_cell__explorer")
    lt_map_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace(@refresh_div,
                   :partial => @refresh_partial,
                   :locals  => {:type       => "container_label_tag_mapping",
                                :action_url => 'label_tag_mapping_field_changed'}) if @refresh_div
      page << javascript_for_miq_button_visibility_changed(@changed)
    end
  end

  # Get variables from label_tag_mapping edit form
  def lt_map_get_form_vars
    @lt_map = @edit[:lt_map]
    @edit[:new][:entity] = params[:entity] if params[:entity]
    @edit[:new][:label_name] = params[:label_name] if params[:label_name]
    @edit[:new][:category] = params[:category] if params[:category]
  end

  def label_tag_mapping_add(entity, label_name, cat_description)
    prefix = ContainerLabelTagMapping::AUTOTAG_PREFIX
    entity_str = entity.nil? ? "" : entity.underscore
    cat_name = "#{prefix}:#{entity_str}:" + Classification.sanitize_name(label_name.tr("/", ":"))

    # UI currently can't allow 2 mappings for same (entity, label).
    if Classification.find_by_name(cat_name)
      add_flash(_("Mapping for %{entity}, %{label} already exists") %
                  {:entity => entity_ui_name_or_all(entity), :label => label_name}, :error)
      javascript_flash
      return
    end

    begin
      ActiveRecord::Base.transaction do
        category = Classification.create_category!(:name         => cat_name,
                                                   :description  => cat_description,
                                                   :single_value => true,
                                                   :read_only    => true)
        ContainerLabelTagMapping.create!(:labeled_resource_type => entity, :label_name => label_name,
                                         :tag => category.tag)
      end
    rescue StandardError => bang
      add_flash(_("Error during 'add': %{message}") % {:message => bang.message}, :error)
      javascript_flash
    else
      add_flash(_("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "ContainerLabelTagMapping"),
                                                       :name  => label_name})
      get_node_info(x_node)
      @lt_map = @edit = session[:edit] = nil # clean out the saved info
      replace_right_cell(:nodetype => "root")
    end
  end

  def label_tag_mapping_update(id, cat_description)
    mapping = ContainerLabelTagMapping.find(id)
    update_category = mapping.tag.classification
    update_category.description = cat_description
    begin
      update_category.save!
    rescue StandardError => bang
      add_flash(_("Error during 'save': %{message}") % {:message => bang.message}, :error)
      javascript_flash
    else
      add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "ContainerLabelTagMapping"),
                                                       :name  => mapping.label_name})
      get_node_info(x_node)
      @lt_map = @edit = session[:edit] = nil # clean out the saved info
      replace_right_cell(:nodetype => "root")
    end
  end

  def label_tag_mapping_delete
    mapping = ContainerLabelTagMapping.find(params[:id])
    category = mapping.tag.category
    label_name = mapping.label_name

    deleted = false
    # delete mapping and category - will indirectly delete tags
    ActiveRecord::Base.transaction do
      deleted = mapping.destroy && category.destroy
    end

    if deleted
      add_flash(_("%{model} \"%{name}\": Delete successful") %
                  {:model => ui_lookup(:model => "ContainerLabelTagMapping"), :name => label_name})
      label_tag_mapping_get_all
      render :update do |page|
        page << javascript_prologue
        page.replace_html 'settings_label_tag_mapping', :partial => 'settings_label_tag_mapping_tab'
      end
    else
      mapping.errors.each { |field, msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      category.errors.each { |field, msg| add_flash("#{field.to_s.capitalize} #{msg}", :error) }
      javascript_flash
    end
  end
end
