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

    {:server => {:rate_limiting => {:api_login => {:limit => 5, :period => 5.minutes}}}}, true,
    {:server => {:rate_limiting => {:api_login => {:limit => 5, :period => "30.seconds"}}}}, true,
    {:server => {:rate_limiting => {:api_login => {:limit => "Five", :period => 30.seconds}}}}, false,
    {:server => {:rate_limiting => {:api_login => {:limit => 5, :period => "Five minutes"}}}}, false,
    {:server => {:rate_limiting => {:api_login => {:limit => 5, :period => nil}}}}, false,
    {:server => {:rate_limiting => {:api_login => {:limit => nil, :period => 5}}}}, false,

    {:server => {:rate_limiting => {:request => {:limit => 5, :period => 5.minutes}}}}, true,
    {:server => {:rate_limiting => {:request => {:limit => 5, :period => "30.seconds"}}}}, true,
    {:server => {:rate_limiting => {:request => {:limit => "Five", :period => 30.seconds}}}}, false,
    {:server => {:rate_limiting => {:request => {:limit => 5, :period => "Five minutes"}}}}, false,
    {:server => {:rate_limiting => {:request => {:limit => 5, :period => nil}}}}, false,
    {:server => {:rate_limiting => {:request => {:limit => nil, :period => 5}}}}, false,

    {:server => {:rate_limiting => {:ui_login => {:limit => 5, :period => 5.minutes}}}}, true,
    {:server => {:rate_limiting => {:ui_login => {:limit => 5, :period => "30.seconds"}}}}, true,
    {:server => {:rate_limiting => {:ui_login => {:limit => "Five", :period => 30.seconds}}}}, false,
    {:server => {:rate_limiting => {:ui_login => {:limit => 5, :period => "Five minutes"}}}}, false,
    {:server => {:rate_limiting => {:ui_login => {:limit => 5, :period => nil}}}}, false,
    {:server => {:rate_limiting => {:ui_login => {:limit => nil, :period => 5}}}}, false,

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

  context "workers section" do
    subject { described_class.new(Settings) }

    it "is invalid with cpu_request_percent > cpu_threshold_percent" do
      stub_settings_merge(:workers => {:worker_base => {:schedule_worker => {:cpu_request_percent => 50, :cpu_threshold_percent => 40}}})
      result, errors = subject.validate
      expect(result).to eql(false)
      expect(errors.first.first).to eql("workers-cpu_request_percent")
      expect(errors.first.last).to include("cannot exceed cpu_threshold_percent")
    end

    it "is invalid with memory_request > memory_threshold" do
      stub_settings_merge(:workers => {:worker_base => {:schedule_worker => {:memory_request => 600.megabytes, :memory_threshold => 500.megabytes}}})
      result, errors = subject.validate
      expect(result).to eql(false)
      expect(errors.first.first).to eql("workers-memory_request")
      expect(errors.first.last).to include("cannot exceed memory_threshold")
    end

    it "is invalid with inherited setting" do
      stub_settings_merge(:workers => {:worker_base => {:defaults => {:cpu_request_percent => 15, :cpu_threshold_percent => 10}}})
      result, errors = subject.validate
      expect(result).to eql(false)
      expect(errors.first.first).to eql("workers-cpu_request_percent")
      expect(errors.first.last).to include("cannot exceed cpu_threshold_percent")
    end

    it "is invalid with overridden worker setting" do
      stub_settings_merge(:workers => {:worker_base => {:defaults => {:cpu_request_percent => 15, :cpu_threshold_percent => 20}, :schedule_worker => {:cpu_threshold_percent => 10}}})
      result, errors = subject.validate
      expect(result).to eql(false)
      expect(errors.first.first).to eql("workers-cpu_request_percent")
      expect(errors.first.last).to include("cannot exceed cpu_threshold_percent")
    end

    it "is invalid if one of the request/limit values is nil" do
      stub_settings_merge(:workers => {:worker_base => {:defaults => {:cpu_request_percent => nil}}})
      result, errors = subject.validate
      expect(result).to eql(false)
      expect(errors.first.first).to eql("workers-cpu_request_percent")
      expect(errors.first.last).to include("has non-numeric value")
    end

    it "is invalid if one of the request/limit values is provided but one is missing" do
      hash = Settings.to_hash
      hash[:workers][:worker_base][:defaults].delete(:cpu_threshold_percent)
      stub_settings(hash)
      result, errors = subject.validate
      expect(result).to eql(false)
      expect(errors.first.first).to eql("workers-cpu_threshold_percent")
      expect(errors.first.last).to include("is missing")
    end

    it "is valid if none of the request/limit values are provided" do
      stub_settings({})
      result, errors = subject.validate
      expect(result).to eql(true)
      expect(errors.empty?).to eql(true)
    end

    it "changing count is valid for a scalable worker" do
      stub_settings_merge(:workers => {:worker_base => {:queue_worker_base => {:generic_worker => {:count => 4}}}})
      result, errors = subject.validate
      expect(result).to be_truthy
      expect(errors.empty?).to eql(true)
    end

    it "changing count is invalid for a non-scalable worker" do
      stub_settings_merge(:workers => {:worker_base => {:queue_worker_base => {:event_handler => {:count => 2}}}})
      result, errors = subject.validate
      expect(result).to be_falsey
      expect(errors).to include("workers-count" => "event_handler: count: 2 exceeds maximum worker count: 1")
    end
  end
end
