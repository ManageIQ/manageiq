module AuthExtensionHelper
  # Finds the appropriate partial name for the given data_type.
  # Does not resolve the entire path, only the name of the partial.
  def auth_partial_for(auth_ext)
    # TODO: support a data picker
    ["string", "int", "float", "date"].include?(auth_ext.data_type) ? "string" : auth_ext.data_type
  end
end
