module ProvidersSettings
  # Method for generating toolbar hash.
  # This method calls calculate_toolbars and build_toolbar(toolbar_name)
  # each button is pushed to array.
  def toolbar_from_hash
    toolbar_items = []
    calculate_toolbars.collect do |_div_id, toolbar_name|
      buttons = toolbar_name ? build_toolbar(toolbar_name) : nil
      toolbar_items.push(buttons)
    end
    toolbar_items
  end

  # Method which creates hash of data from model.
  # First record from get_view method is actual view.
  # This view is sent to view_to_hash(view) and here are fetched data as hash.
  def generate_providers
    view, _view_pages = get_view(model)[0]
    view_to_hash(view)
  end

  # Method for mapping array of types to hashed type.
  # @param provider_types [[key, item], [key, item]]
  # = {
  #   :id => key,
  #   :title => item
  # }
  def types_to_hash(provider_types)
    types = []
    provider_types.each do |item, key|
      types.push(:id => key, :title => item)
    end
    types
  end

  # Method for adding basic view templates.
  # Call this if you want to add basic templates, also create new html
  # views/static/controller_name/new_provider/[basic_information, detail_info].html
  # if you want to have different location for these you can add views to each type
  # views => {
  #   "basic_information" => "location/to/html/file.html",
  #   "detail_info" => "location/to/html/file.html"
  # }
  def new_provider_views(types)
    types.each do |item|
      item[:templates] = %w(basic_information detail_info)
    end
  end

  def default_list_providers_settings
    {
      :isSelectable => true,
      :noFooter     => false,
      :hasHeader    => true,
      :title        => @title,
      :newProvider  => _("Add New %{model}") % {:model => ui_lookup(:table => @table_name)}
    }
  end

  #### default routes, defined in router.rb

  def toolbar_settings
    @lastaction = params[:is_list] != "false" ? 'show_list' : nil
    @gtl_type = params[:glt_type]
    @record = !params[:id].nil? && identify_record(params[:id])
    render :json => toolbar_from_hash
  end

  def list_providers_settings
    render :json => default_list_providers_settings
  end
end
