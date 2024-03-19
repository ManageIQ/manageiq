class <%= class_name %>::<%= manager_type %> < ManageIQ::Providers::<%= manager_type %>
  supports :create

  # Form schema for creating/editing a provider, it should follow the DDF specification
  # For more information check the DDF documentation at: https://data-driven-forms.org
  #
  # If for some reason some fields should not be included in the submitted data, there's
  # a `skipSubmit` flag. This is useful for components that provide local-only behavior,
  # like the validate-provider-credentials or protocol-selector.
  #
  # There's validation built on top on these fields in the API, so if some field isn't
  # specified here, the API endpoint won't allow the request to go through.
  # Make sure you don't dot-prefix match any field with any other field, because it can
  # confuse the validation. For example you should not have `x` and `x.y` fields at the
  # same time.
  def self.params_for_create
    {
      :fields => [
        {
          :component => 'sub-form',
          :name      => 'endpoints-subform',
          :title     => _('Endpoints'),
          :fields    => [
            {
              :component              => 'validate-provider-credentials',
              :name                   => 'authentications.default.valid',
              :skipSubmit             => true,
              :validationDependencies => %w[type zone_id provider_region],
              :fields                 => [
                {
                  :component    => "select",
                  :id           => "endpoints.default.verify_ssl",
                  :name         => "endpoints.default.verify_ssl",
                  :label        => _("SSL verification"),
                  :dataType     => "integer",
                  :isRequired   => true,
                  :validate     => [{:type => "required"}],
                  :initialValue => OpenSSL::SSL::VERIFY_PEER,
                  :options      => [
                    {
                      :label => _('Do not verify'),
                      :value => OpenSSL::SSL::VERIFY_NONE,
                    },
                    {
                      :label => _('Verify'),
                      :value => OpenSSL::SSL::VERIFY_PEER,
                    },
                  ]
                },
                {
                  :component  => "text-field",
                  :name       => "endpoints.default.hostname",
                  :label      => _("Hostname (or IPv4 or IPv6 address)"),
                  :isRequired => true,
                  :validate   => [{:type => "required"}],
                },
                {
                  :component    => "text-field",
                  :name         => "endpoints.default.port",
                  :label        => _("API Port"),
                  :type         => "number",
                  :initialValue => 12345,
                  :isRequired   => true,
                  :validate     => [{:type => "required"}]
                },
                {
                  :component  => "text-field",
                  :name       => "authentications.default.userid",
                  :label      => "Username",
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
                {
                  :component  => "password-field",
                  :name       => "authentications.default.password",
                  :label      => "Password",
                  :type       => "password",
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
              ]
            }
          ]
        }
      ]
    }
  end

  def self.verify_credentials(args)
    # Verify the credentials without having an actual record created.
    # This method is being called from the UI upon validation when adding/editing a provider via DDF
    # Ideally it should pass the args with some kind of mapping to the connect method
  end

  def verify_credentials(auth_type = nil, options = {})
    begin
      connect
    rescue => err
      raise MiqException::MiqInvalidCredentialsError, err.message
    end

    true
  end

  def connect(options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    auth_token = authentication_token(options[:auth_type])
    self.class.raw_connect(project, auth_token, options, options[:proxy_uri] || http_proxy_uri)
  end

  def self.validate_authentication_args(params)
    # return args to be used in raw_connect
    return [params[:default_userid], ManageIQ::Password.encrypt(params[:default_password])]
  end

  def self.hostname_required?
    # TODO: ExtManagementSystem is validating this
    false
  end

  def self.raw_connect(*args)
    # TODO: Replace this with a client connection from your Ruby SDK library and remove the MyRubySDK class
    MyRubySDK.new
  end

  def self.ems_type
    @ems_type ||= "<%= provider_name %>".freeze
  end

  def self.description
    @description ||= "<%= provider_name.split('_').map(&:capitalize).join(' ') %>".freeze
  end

  # TODO: This class represents a fake Ruby SDK with sample data.
  #       Remove this and use a real Ruby SDK in the raw_connect method
  class MyRubySDK
    def vms
      [
        OpenStruct.new(
          :id       => '1',
          :name     => 'funky',
          :location => 'dc-1',
          :vendor   => 'unknown'
        ),
        OpenStruct.new(
          :id       => '2',
          :name     => 'bunch',
          :location => 'dc-1',
          :vendor   => 'unknown'
        ),
      ]
    end

    def find_vm(id)
      vms.find { |v| v.id == id.to_s }
    end

    def events
      [
        OpenStruct.new(
          :name       => %w(instance_power_on instance_power_off).sample,
          :id         => Time.zone.now.to_i,
          :timestamp  => Time.zone.now,
          :vm_ems_ref => [1, 2].sample
        ),
        OpenStruct.new(
          :name       => %w(instance_power_on instance_power_off).sample,
          :id         => Time.zone.now.to_i + 1,
          :timestamp  => Time.zone.now,
          :vm_ems_ref => [1, 2].sample
        )
      ]
    end

    def metrics(start_time, end_time)
      timestamp = start_time
      metrics = {}
      while (timestamp < end_time)
        metrics[timestamp] = {
          'cpu_usage_rate_average'  => rand(100).to_f,
          'disk_usage_rate_average' => rand(100).to_f,
          'mem_usage_rate_average'  => rand(100).to_f,
          'net_usage_rate_average'  => rand(100).to_f,
        }
        timestamp += 20.seconds
      end
      metrics
    end
  end
end
