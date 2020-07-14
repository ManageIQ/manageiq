class <%= class_name %>::<%= manager_type %> < ManageIQ::Providers::<%= manager_type %>
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :Vm

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
    @params_for_create ||= {
      :fields => [
        {
          :component => "text-field",
          :name      => "provider_region",
          :label     => _("Provider Region"),
        },
        {
          :component => 'sub-form',
          :name      => 'endpoints-subform',
          :title     => _('Endpoints'),
          :fields    => [
            {
              :component              => 'validate-provider-credentials',
              :name                   => 'authentications.default.valid',
              :skipSubmit             => true,
              :validationDependencies => %w[type provider_region],
              :fields                 => [
                {
                  :component  => "select-field",
                  :name       => "endpoints.default.security_protocol",
                  :label      => _("Security Protocol"),
                  :isRequired => true,
                  :validate   => [{:type => "required-validator"}],
                  :options    => [
                    {
                      :label => _("SSL without validation"),
                      :value => "ssl-no-validation"
                    },
                    {
                      :label => _("SSL"),
                      :value => "ssl-with-validation"
                    },
                    {
                      :label => _("Non-SSL"),
                      :value => "non-ssl"
                    }
                  ]
                },
                {
                  :component  => "text-field",
                  :name       => "endpoints.default.hostname",
                  :label      => _("Hostname (or IPv4 or IPv6 address)"),
                  :isRequired => true,
                  :validate   => [{:type => "required-validator"}],
                },
                {
                  :component    => "text-field",
                  :name         => "endpoints.default.port",
                  :label        => _("API Port"),
                  :type         => "number",
                  :initialValue => 12345,
                  :isRequired   => true,
                  :validate     => [{:type => "required-validator"}],
                },
                {
                  :component  => "text-field",
                  :name       => "authentications.default.userid",
                  :label      => "Username",
                  :isRequired => true,
                  :validate   => [{:type => "required-validator"}],
                },
                {
                  :component  => "password-field",
                  :name       => "authentications.default.password",
                  :label      => "Password",
                  :type       => "password",
                  :isRequired => true,
                  :validate   => [{:type => "required-validator"}],
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
    true
  end

  def self.ems_type
    @ems_type ||= "<%= provider_name %>".freeze
  end

  def self.description
    @description ||= "<%= provider_name.split('_').map(&:capitalize).join(' ') %>".freeze
  end
end
