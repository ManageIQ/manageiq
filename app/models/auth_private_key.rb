class AuthPrivateKey < Authentication
  def assign_values(options)
    # this string parsing will be removed when moving to file uploads, dont review
    new_auth_key = options["auth_key"][0..30] + options["auth_key"][31..-30].tr(" ", "\n") + options["auth_key"][-29..-1]
    options["auth_key"] = new_auth_key
    super
  end
end
