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
end
