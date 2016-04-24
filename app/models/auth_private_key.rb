class AuthPrivateKey < Authentication
  def assign_values(options)
    new_auth_key = options["auth_key"][0..30] + options["auth_key"][31..-30].gsub(" ", "\n") + options["auth_key"][-29..-1]
    options["auth_key"] = new_auth_key
    super
  end

end
