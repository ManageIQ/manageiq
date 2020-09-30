RSpec.describe AuthUseridPassword do
  describe ".encrypted_columns" do
    it "returns the encrypted columns" do
      expected = %w[password auth_key service_account auth_key_password become_password]
      expect(described_class.encrypted_columns).to match_array(expected)
    end
  end
end
