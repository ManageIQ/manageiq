class AuthenticationRequestHeader < Authentication

  def generate_ansible_entry
    options = {}
    options["challengeURL"] = request_header_challenge_url
    options["loginURL"] = request_header_login_url
    options["clientCA"] = certificate_authority
    options["headers"] = request_header_headers
    options["request_header_preferred_username_headers"] = request_header_preferred_username_headers
    options["request_header_name_headers"] = request_header_name_headers
    options["request_header_email_headers"] = request_header_email_headers
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["challengeURL"] = request_header_challenge_url
    options["loginURL"] = request_header_login_url
    options["clientCA"] = certificate_authority
    options["headers"] = request_header_headers
    options["request_header_preferred_username_headers"] = request_header_preferred_username_headers
    options["request_header_name_headers"] = request_header_name_headers
    options["request_header_email_headers"] = request_header_email_headers
    ansible_config options
  end

  def assign_values(options)
    hash = {}
    hash["certificate_authority"] = options["clientCA"]
    hash["request_header_challenge_url"] = options["challengeUrl"]
    hash["request_header_login_url"] = options["loginUrl"]
    hash["request_header_headers"] = options["headers"]
    super hash
  end
end
