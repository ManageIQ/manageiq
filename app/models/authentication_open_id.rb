class AuthenticationOpenId < Authentication

  def generate_ansible_entry
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password_encrypted
    options["claims"] = {}
    options["claims"]["id"] = open_id_sub_claim
    options["urls"] = {}
    options["urls"]["authorize"] = open_id_authorization_endpoint
    options["urls"]["toekn"] = open_id_token_endpoint
    options["challenge"] = "false"
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password_encrypted
    options["claims"] = {}
    options["claims"]["id"] = open_id_sub_claim
    options["urls"] = {}
    options["urls"]["authorize"] = open_id_authorization_endpoint
    options["urls"]["toekn"] = open_id_token_endpoint
    options["challenge"] = "false"
    ansible_config options
  end

  def assign_values(options)
    hash = {}
    hash["password"] = options["clientSecret"]
    hash["certificate_authority"] = options["clientCA"]
    hash["userid"] = options["clientId"]
    hash["open_id_sub_claim"] = options["subClaim"]
    hash["open_id_authorization_endpoint"] = options["authEndpoint"]
    hash["open_id_token_endpoint"] = options["tokenEndpoint"]
    super hash
  end
end
