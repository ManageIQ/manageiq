module ManageIQ::Providers::Openstack::HelperMethods
  def parse_error_message_from_fog_response(exception)
    exception_string = exception.to_s
    matched_message = exception_string.match(/message\\\": \\\"(.*)\\\", /)
    matched_message ? matched_message[1] : exception_string
  end
end
