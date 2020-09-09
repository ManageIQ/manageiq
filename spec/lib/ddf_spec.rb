RSpec.describe DDF do
  let(:userid_field) do
    {
      :component  => "text-field",
      :id         => "authentications.default.userid",
      :name       => "authentications.default.userid",
      :label      => _("Username"),
      :helperText => _("Should have privileged access, such as root or administrator."),
      :isRequired => true,
      :validate   => [{:type => "required"}]
    }
  end

  let(:schema) do
    {
      :fields => [
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _("Endpoint"),
          :fields    => [
            {
              :component              => 'validate-provider-credentials',
              :id                     => 'authentications.default.valid',
              :name                   => 'authentications.default.valid',
              :skipSubmit             => true,
              :validationDependencies => %w[type zone_id],
              :fields                 => [
                {
                  :component  => "text-field",
                  :id         => "endpoints.default.url",
                  :name       => "endpoints.default.url",
                  :label      => _("URL"),
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
                {
                  :component    => "select",
                  :id           => "endpoints.default.verify_ssl",
                  :name         => "endpoints.default.verify_ssl",
                  :label        => _("SSL verification"),
                  :isRequired   => true,
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
                userid_field,
                {
                  :component  => "password-field",
                  :id         => "authentications.default.password",
                  :name       => "authentications.default.password",
                  :label      => _("Password"),
                  :type       => "password",
                  :isRequired => true,
                  :validate   => [{:type => "required"}]
                },
              ],
            },
          ],
        },
      ]
    }.freeze
  end

  it ".extract_attributes" do
    expect(described_class.extract_attributes(schema, :id)).to eq %w[
      endpoints-subform
      authentications.default.valid
      endpoints.default.url
      endpoints.default.verify_ssl
      authentications.default.userid
      authentications.default.password
    ]
  end

  describe ".find_field" do
    it "when field is found" do
      expect(described_class.find_field(schema, userid_field[:id])).to equal userid_field
    end

    it "when field is not found" do
      expect(described_class.find_field(schema, 'foo')).to be_nil
    end
  end
end
