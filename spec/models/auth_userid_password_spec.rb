RSpec.describe AuthUseridPassword do
  describe ".encrypted_columns" do
    it "returns the encrypted columns" do
      expected = %w(password password_encrypted auth_key auth_key_encrypted service_account service_account_encrypted auth_key_password auth_key_password_encrypted become_password become_password_encrypted)
      expect(described_class.encrypted_columns).to match_array(expected)
    end
  end
end
