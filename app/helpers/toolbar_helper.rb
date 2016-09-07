module ToolbarHelper
  # Method for generating toolbar hash.
  # This method calls calculate_toolbars and build_toolbar(toolbar_name)
  # each button is pushed to array.
  def toolbar_from_hash
    calculate_toolbars.collect do |_div_id, toolbar_name|
      toolbar_name ? build_toolbar(toolbar_name) : nil
    end
  end
end
