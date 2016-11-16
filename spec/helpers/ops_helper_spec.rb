describe OpsHelper do
  describe '#auth_mode_name' do
    modes = %w(ldap ldaps amazon httpd database)
    modes_pretty = %w(LDAP LDAPS Amazon External\ Authentication Database)

    modes.zip modes_pretty.each do |mode, mode_pretty|
      it "Returns #{mode_pretty} when mode is #{mode}" do
        stub_settings(:authentication => {:mode => mode}, :server => {})
        expect(helper.auth_mode_name).to eq(mode_pretty)
      end
    end
  end
end
