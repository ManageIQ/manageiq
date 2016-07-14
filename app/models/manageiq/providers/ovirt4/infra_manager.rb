require 'ovirtsdk4'

class ManageIQ::Providers::Ovirt4::InfraManager < ManageIQ::Providers::InfraManager
  # Connect to the engine using version 3 of the API and the `ovirt` gem.
  def connect(opts = {})
    raise "No credentials defined" if self.missing_credentials?(opts[:auth_type])

    # If there is API path stored in the endpoints table then use it:
    path = default_endpoint.path

    # Calculate the connection parameters:
    host     = opts[:ip] || address
    port     = opts[:port] || self.port
    username = opts[:user] || authentication_userid(opts[:auth_type])
    password = opts[:pass] || authentication_password(opts[:auth_type])

    # Create the connection:
    connection = OvirtSDK4::Connection.new(
      :url      => "https://#{host}:#{port}#{path}",
      :username => username,
      :password => password,
      :insecure => true,
      :debug    => true,
      :log      => $ovirt4_log,
    )

    # Return the connection:
    connection
  end
end
