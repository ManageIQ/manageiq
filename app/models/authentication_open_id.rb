class AuthenticationOpenId < Authentication

  #will be removed once moving to yaml format, no need to review method
  def generate_ansible_entry
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password
    options["claims"] = {}
    options["claims"]["id"] = open_id_sub_claim
    options["urls"] = {}
    options["urls"]["authorize"] = open_id_authorization_endpoint
    options["urls"]["toekn"] = open_id_token_endpoint
    options["challenge"] = "false"
    options["open_id_extra_authorize_parameters"] = open_id_extra_authorize_parameters
    options["open_id_extra_scopes"] = open_id_extra_scopes
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password
    options["claims"] = {}
    options["claims"]["id"] = open_id_sub_claim
    options["urls"] = {}
    options["urls"]["authorize"] = open_id_authorization_endpoint
    options["urls"]["toekn"] = open_id_token_endpoint
    options["challenge"] = "false"
    options["open_id_extra_authorize_parameters"] = open_id_extra_authorize_parameters
    options["open_id_extra_scopes"] = open_id_extra_scopes
    ansible_config options
  end
end
