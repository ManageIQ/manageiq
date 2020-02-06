RSpec.describe Vmdb::Settings::Validator do
  describe ".new" do
    it "with a Hash" do
      validator = described_class.new(:session => {:timeout => 123})
      expect(validator).to be_valid
    end

    it "with a Config::Options" do
      validator = described_class.new(Settings)
      expect(validator).to be_valid
    end
  end

  VALIDATOR_CASES = [
    {:webservices => {:mode => "invoke"}}, true,
    {:webservices => {:mode => "xxx"}},    false,

    {:webservices => {:contactwith => "ipaddress"}}, true,
    {:webservices => {:contactwith => "xxx"}},       false,

    {:webservices => {:nameresolution => true}},  true,
    {:webservices => {:nameresolution => "xxx"}}, false,

    {:webservices => {:timeout => 123}},   true,
    {:webservices => {:timeout => "xxx"}}, false,

    {:authentication => {:mode => "ldaps"}},                     false,
    {:authentication => {:mode => "ldaps", :ldaphost => "foo"}}, true,
    {:authentication => {:mode => "xxx"}},                       false,

    {:authentication => {:mode => "ldap", :ldaphost => "foo"}}, true,
    {:authentication => {:mode => "ldap", :ldaphost => nil}},   false,
    {:authentication => {:mode => "ldap", :ldaphost => ""}},    false,
    {:authentication => {:mode => "ldap"}},                     false,

    {:log => {:level => "debug"}}, true,
    {:log => {:level => "xxx"}},   false,

    {:log => {:level_rails => "debug"}}, true,
    {:log => {:level_rails => "xxx"}},   false,

    {:session => {:timeout => 123}},   true,
    {:session => {:timeout => "xxx"}}, false,
    {:session => {:timeout => 0}},     false,

    {:session => {:interval => 123}},   true,
    {:session => {:interval => "xxx"}}, false,
    {:session => {:interval => 0}},     false,

    {:server => {:listening_port => 123}},   true,
    {:server => {:listening_port => nil}},   true,
    {:server => {:listening_port => "xxx"}}, false,

    {:server => {:session_store => "cache"}}, true,
    {:server => {:session_store => "xxx"}},   false,

    {:smtp => {:authentication => "none"}}, true,
    {:smtp => {:authentication => "xxx"}},  false,

    {:smtp => {:authentication => "login", :user_name => "foo"}}, true,
    {:smtp => {:authentication => "login", :user_name => nil}},   false,
    {:smtp => {:authentication => "login", :user_name => ""}},    false,
    {:smtp => {:authentication => "login"}},                      false,

    {:smtp => {:port => 123}},   true,
    {:smtp => {:port => "xxx"}}, false,

    {:smtp => {:from => "a@example.com"}}, true,
    {:smtp => {:from => "xxx"}},           false,
  ].freeze

  VALIDATOR_CASES.each_slice(2) do |c, expected|
    it c do
      validator = described_class.new(c)
      expect(validator.valid?).to be expected
    end
  end
end
