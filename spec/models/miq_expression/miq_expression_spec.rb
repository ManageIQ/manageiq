describe MiqExpression do
  let(:exp) { {"=" => {"field" => "Vm-name", "value" => "test"}} }
  let(:qs_exp) { {"=" => {"field" => "Vm-name", "value" => :user_input}} }
  let(:complex_qs_exp) do
    {"AND" => [
      {"=" => {"field" => "Vm-name", "value" => "test"}}, {"=" => {"field" => "Vm-name", "value" => :user_input}}
    ]}
  end

  describe ".to_ruby" do
    # Based on FogBugz 6181: something INCLUDES []
    it "detects value empty array" do
      exp = MiqExpression.new("INCLUDES" => {"field" => "Vm-name", "value" => "/[]/"})
      expect(exp.to_ruby).to eq("<value ref=vm, type=string>/virtual/name</value> =~ /\\/\\[\\]\\//")
    end

    it "raises error if expression contains ruby script" do
      exp = MiqExpression.new("RUBY" => {"field" => "Host-name", "value" => "puts 'Hello world!'"})
      expect { exp.to_ruby }.to raise_error(RuntimeError, "Ruby scripts in expressions are no longer supported. Please use the regular expression feature of conditions instead.")
    end
  end

  context "value2tag" do
    it "virtual default" do
      expect(described_class.value2tag("env")).to eq ["env", "/virtual"]
    end

    it "dotted notation" do
      expect(described_class.value2tag("env.prod.ny")).to eq ["env", "/virtual/prod/ny"]
    end

    it "with value" do
      expect(described_class.value2tag("env", "thing1")).to eq ["env", "/virtual/thing1"]
    end

    it "dotted notation with value" do
      expect(described_class.value2tag("env.prod.ny", "thing1")).to eq ["env", "/virtual/prod/ny/thing1"]
    end

    it "value with escaped slash" do
      expect(described_class.value2tag("env.prod.ny", "thing1/thing2")).to eq ["env", "/virtual/prod/ny/thing1%2fthing2"]
    end

    it "user_tag" do
      expect(described_class.value2tag("env.user_tag.ny", "thing1")).to eq ["env", "/user/ny/thing1"]
    end

    it "model and column" do
      expect(described_class.value2tag("env.vm-name", "thing1")).to eq ["env", "/virtual/vm/name/thing1"]
    end

    it "managed" do
      expect(described_class.value2tag("env.managed.host", "thing1")).to eq ["env", "/managed/host/thing1"]
    end

    it "managed" do
      expect(described_class.value2tag("env.managed.host")).to eq ["env", "/managed/host"]
    end

    it "false value" do
      expect(described_class.value2tag("MiqGroup.vms-disconnected", false)).to eq ["miqgroup", "/virtual/vms/disconnected/false"]
    end
  end

  it "supports yaml" do
    exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      "=":
        field: Host-enabled_inbound_ports
        value: "22,427,5988,5989"
    '
    expect(exp.to_ruby).to eq('<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> == [22,427,5988,5989]')
  end

  it "tests numeric set expressions" do
    exp = MiqExpression.new("=" => {"field" => "Host-enabled_inbound_ports", "value" => "22,427,5988,5989"})
    expect(exp.to_ruby).to eq('<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> == [22,427,5988,5989]')
  end

  it "expands ranges" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ALL:
        field: Host-enabled_inbound_ports
        value: 22, 427, 5988, 5989, 1..4
    '
    expect(filter.to_ruby).to eq('(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> & [1,2,3,4,22,427,5988,5989]) == [1,2,3,4,22,427,5988,5989]')

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ANY:
        field: Host-enabled_inbound_ports
        value: 22, 427, 5988, 5989, 1..3
    '

    expect(filter.to_ruby).to eq('([1,2,3,22,427,5988,5989] - <value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value>) != [1,2,3,22,427,5988,5989]')

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ONLY:
        field: Host-enabled_inbound_ports
        value: 22
    '
    expect(filter.to_ruby).to eq('(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [22]) == []')

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      LIMITED TO:
        field: Host-enabled_inbound_ports
        value: 22
    '
    expect(filter.to_ruby).to eq('(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [22]) == []')
  end

  it "should test string set expressions" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      "=":
        field: Host-service_names
        value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("<value ref=host, type=string_set>/virtual/service_names</value> == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']")

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ALL:
        field: Host-service_names
        value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("(<value ref=host, type=string_set>/virtual/service_names</value> & ['ntpd','sshd','vmware-vpxa','vmware-webAccess']) == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']")

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ANY:
        field: Host-service_names
        value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("(['ntpd','sshd','vmware-vpxa','vmware-webAccess'] - <value ref=host, type=string_set>/virtual/service_names</value>) != ['ntpd','sshd','vmware-vpxa','vmware-webAccess']")

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ONLY:
        field: Host-service_names
        value: "ntpd, sshd, vmware-vpxa"
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []")

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      LIMITED TO:
        field: Host-service_names
        value: "ntpd, sshd, vmware-vpxa"
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []")

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      FIND:
        search:
          "=":
            field: Host.filesystems-name
            value: /etc/passwd
        checkall:
          "=":
            field: Host.filesystems-permissions
            value: "0644"
    '
    # filter.to_human
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<find><search><value ref=host, type=text>/virtual/filesystems/name</value> == "/etc/passwd"</search><check mode=all><value ref=host, type=string>/virtual/filesystems/permissions</value> == "0644"</check></find>')
  end

  it "should test regexp" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      REGULAR EXPRESSION MATCHES:
        field: Host-name
        value: /^[^.]*\.galaxy\..*$/
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/')

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      REGULAR EXPRESSION MATCHES:
        field: Host-name
        value: ^[^.]*\.galaxy\..*$
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/')

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      FIND:
        search:
          "=":
            field: Host.firewall_rules-enabled
            value: "true"
        checkany:
          REGULAR EXPRESSION MATCHES:
            field: Host.firewall_rules-name
            value: /^.*SLP.*$/'

    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == "true"</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> =~ /^.*SLP.*$/</check></find>')

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      FIND:
        search:
          "=":
            field: Host.firewall_rules-enabled
            value: "true"
        checkany:
          REGULAR EXPRESSION DOES NOT MATCH:
            field: Host.firewall_rules-name
            value: /^.*SLP.*$/'

    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == "true"</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> !~ /^.*SLP.*$/</check></find>')
  end

  it "should test fb7726" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      CONTAINS:
        field: Host.filesystems-name
        value: /etc/shadow
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("<exist ref=host>/virtual/filesystems/name/%2fetc%2fshadow</exist>")
  end

  it "should escape strings" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES:
        field: Vm.registry_items-data
        value: $foo
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("<value ref=vm, type=text>/virtual/registry_items/data</value> =~ /\\$foo/")

    data = {"registry_items.data" => "C:\\Documents and Users\\O'Neill, April\\", "/virtual/registry_items/data" => "C:\\Documents and Users\\O'Neill, April\\"}
    expect(Condition.subst(filter.to_ruby, data, {})).to eq("\"C:\\\\Documents and Users\\\\O'Neill, April\\\\\" =~ /\\$foo/")
  end

  it "should test context hash" do
    data = {"name" => "VM_1", "guest_applications.version" => "3.1.2.7193", "guest_applications.release" => nil, "guest_applications.vendor" => "VMware, Inc.", "id" => 9, "guest_applications.name" => "VMware Tools", "guest_applications.package_name" => nil}

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      "=":
        field: Vm.guest_applications-name
        value: VMware Tools
    context_type: hash
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("<value type=string>guest_applications.name</value> == \"VMware Tools\"")
    expect(Condition.subst(filter.to_ruby, data, {})).to eq("\"VMware Tools\" == \"VMware Tools\"")

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      REGULAR EXPRESSION MATCHES:
        field: Vm.guest_applications-vendor
        value: /^[^.]*ware.*$/
    context_type: hash
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq("<value type=string>guest_applications.vendor</value> =~ /^[^.]*ware.*$/")
    expect(Condition.subst(filter.to_ruby, data, {})).to eq('"VMware, Inc." =~ /^[^.]*ware.*$/')
  end

  it "should test numbers with methods" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      ">=":
        field: Vm-memory_shares
        value: 25.kilobytes
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<value ref=vm, type=integer>/virtual/memory_shares</value> >= 25600')

    filter = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      ">=":
        field: Vm-used_disk_storage
        value: 1,000.megabytes
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    expect(filter.to_ruby).to eq('<value ref=vm, type=integer>/virtual/used_disk_storage</value> >= 1048576000')
  end

  # end to_ruby

  describe ".atom_error" do
    it "should test atom error" do
      expect(MiqExpression.atom_error("Host-xx", "regular expression matches", '123[)')).not_to be_falsey

      expect(MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '')).not_to be_falsey
      expect(MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '123abc')).not_to be_falsey
      expect(MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '123')).to be_falsey
      expect(MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '123.456')).to be_falsey
      expect(MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '2,123.456')).to be_falsey

      expect(MiqExpression.atom_error("Vm-cpu_limit", "=", '')).not_to be_falsey
      expect(MiqExpression.atom_error("Vm-cpu_limit", "=", '123.5')).not_to be_falsey
      expect(MiqExpression.atom_error("Vm-cpu_limit", "=", '123.5.abc')).not_to be_falsey
      expect(MiqExpression.atom_error("Vm-cpu_limit", "=", '123')).to be_falsey
      expect(MiqExpression.atom_error("Vm-cpu_limit", "=", '2,123')).to be_falsey

      expect(MiqExpression.atom_error("Vm-created_on", "=", Time.now.to_s)).to be_falsey
      expect(MiqExpression.atom_error("Vm-created_on", "=", "123456")).not_to be_falsey
    end
  end

  context "._model_details" do
    it "should not be overly aggressive in filtering out columns for logical CPUs" do
      relats  = MiqExpression.get_relats(Vm)
      details = MiqExpression._model_details(relats, {})
      cluster_sorted = details.select { |d| d.first.starts_with?("Cluster") }.sort
      expect(cluster_sorted.map(&:first)).to include("Cluster / Deployment Role : Total Number of Physical CPUs")
      expect(cluster_sorted.map(&:first)).to include("Cluster / Deployment Role : Total Number of Logical CPUs")
      hardware_sorted = details.select { |d| d.first.starts_with?("Hardware") }.sort
      expect(hardware_sorted.map(&:first)).not_to include("Hardware : Logical Cpus")
    end

    it "should not contain duplicate tag fields" do
      # tags contain the root tenant's name
      Tenant.seed

      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      FactoryGirl.create(:classification, :parent_id => category.id, :name => 'prod', :description => 'Production')
      tags = MiqExpression.model_details('Host',
                                         :typ             => 'tag',
                                         :include_model   => true,
                                         :include_my_tags => false,
                                         :userid          => 'admin')
      expect(tags.uniq.length).to eq(tags.length)
    end
  end

  context ".build_relats" do
    it "includes reflections from descendant classes of Vm" do
      relats = MiqExpression.get_relats(Vm)
      expect(relats[:reflections][:cloud_tenant]).not_to be_blank
    end

    it "includes reflections from descendant classes of Host" do
      relats = MiqExpression.get_relats(Host)
      expect(relats[:reflections][:cloud_networks]).not_to be_blank
    end

    it "excludes reflections from descendant classes of VmOrTemplate " do
      relats = MiqExpression.get_relats(VmOrTemplate)
      expect(relats[:reflections][:cloud_tenant]).to be_blank
    end
  end

  context "Date/Time Support" do
    context "Testing expression conversion ruby, sql and human with static dates and times" do
      it "should generate the correct ruby expression with an expression having static dates and times with no time zone" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")

        exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")

        exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")

        exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-10'.to_date")

        exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date <= '2011-01-10'.to_date")

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T09:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T09:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date == '2011-01-10'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T23:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-09'.to_date && val.to_date <= '2011-01-10'.to_date")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-09'.to_date && val.to_date <= '2011-01-10'.to_date")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T08:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T17:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T00:00:00Z'.to_time(:utc)")
      end

      it "should generate the correct ruby expression running to_ruby with an expression having static dates and times with a time zone" do
        tz = "Eastern Time (US & Canada)"

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")

        exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")

        exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")

        exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-10'.to_date")

        exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date <= '2011-01-10'.to_date")

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T14:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T14:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date == '2011-01-10'.to_date")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-09'.to_date && val.to_date <= '2011-01-10'.to_date")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T13:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T22:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T05:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T05:00:00Z'.to_time(:utc)")
      end

      it "should generate the correct SQL query running to_sql with an expression having static dates and times with no time zone" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on > '2011-01-10'")

        exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on > '2011-01-10'")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on < '2011-01-10'")

        exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on < '2011-01-10'")

        exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on >= '2011-01-10'")

        exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on <= '2011-01-10'")

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on > '2011-01-10T09:00:00Z'")

        exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on > '2011-01-10T09:00:00Z'")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on = '2011-01-10'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on BETWEEN '2011-01-09' AND '2011-01-10'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on BETWEEN '2011-01-09' AND '2011-01-10'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on BETWEEN '2011-01-10T08:00:00Z' AND '2011-01-10T17:00:00Z'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on BETWEEN '2011-01-10T00:00:00Z' AND '2011-01-10T00:00:00Z'")
      end

      it "should generate the correct human expression with an expression having static dates and times with no time zone" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On AFTER "2011-01-10"')

        exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On > "2011-01-10"')

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On BEFORE "2011-01-10"')

        exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On < "2011-01-10"')

        exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On >= "2011-01-10"')

        exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On <= "2011-01-10"')

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time AFTER "2011-01-10 9:00"')

        exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time > "2011-01-10 9:00"')

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On IS "2011-01-10"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        expect(exp.to_human).to eq('VM and Instance : Retires On FROM "2011-01-09" THROUGH "2011-01-10"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
        expect(exp.to_human).to eq('VM and Instance : Retires On FROM "01/09/2011" THROUGH "01/10/2011"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "2011-01-10 8:00" THROUGH "2011-01-10 17:00"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "2011-01-10 00:00" THROUGH "2011-01-10 00:00"')
      end
    end

    context "Testing expression conversion to ruby with relative dates and times" do
      before(:each) do
        Timecop.freeze("2011-01-11 17:30 UTC")
      end

      after(:each) do
        Timecop.return
      end

      it ".normalize_date_time" do
        # Test <value> <interval> Ago
        expect(MiqExpression.normalize_date_time("3 Hours Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 14:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Hours Ago", "UTC").utc.to_s).to eq("2011-01-11 14:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Hours Ago", "UTC", "end").utc.to_s).to eq("2011-01-11 14:59:59 UTC")

        expect(MiqExpression.normalize_date_time("3 Days Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-08 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Days Ago", "UTC").utc.to_s).to eq("2011-01-08 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Days Ago", "UTC", "end").utc.to_s).to eq("2011-01-08 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("3 Weeks Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-12-20 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Weeks Ago", "UTC").utc.to_s).to eq("2010-12-20 00:00:00 UTC")

        expect(MiqExpression.normalize_date_time("4 Months Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-09-01 04:00:00 UTC")
        expect(MiqExpression.normalize_date_time("4 Months Ago", "UTC").utc.to_s).to eq("2010-09-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("4 Months Ago", "UTC", "end").utc.to_s).to eq("2010-09-30 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("1 Quarter Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-10-01 04:00:00 UTC")
        expect(MiqExpression.normalize_date_time("1 Quarter Ago", "UTC").utc.to_s).to eq("2010-10-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("1 Quarter Ago", "UTC", "end").utc.to_s).to eq("2010-12-31 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("3 Quarters Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-04-01 04:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Quarters Ago", "UTC").utc.to_s).to eq("2010-04-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("3 Quarters Ago", "UTC", "end").utc.to_s).to eq("2010-06-30 23:59:59 UTC")

        # Test Now, Today, Yesterday
        expect(MiqExpression.normalize_date_time("Now", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Now", "UTC").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Now", "UTC", "end").utc.to_s).to eq("2011-01-11 17:59:59 UTC")

        expect(MiqExpression.normalize_date_time("Today", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Today", "UTC").utc.to_s).to eq("2011-01-11 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Today", "UTC", "end").utc.to_s).to eq("2011-01-11 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("Yesterday", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-10 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Yesterday", "UTC").utc.to_s).to eq("2011-01-10 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Yesterday", "UTC", "end").utc.to_s).to eq("2011-01-10 23:59:59 UTC")

        # Test Last ...
        expect(MiqExpression.normalize_date_time("Last Hour", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 16:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Hour", "UTC").utc.to_s).to eq("2011-01-11 16:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Hour", "UTC", "end").utc.to_s).to eq("2011-01-11 16:59:59 UTC")

        expect(MiqExpression.normalize_date_time("Last Week", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-03 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Week", "UTC").utc.to_s).to eq("2011-01-03 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Week", "UTC", "end").utc.to_s).to eq("2011-01-09 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("Last Month", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-12-01 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Month", "UTC").utc.to_s).to eq("2010-12-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Month", "UTC", "end").utc.to_s).to eq("2010-12-31 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("Last Quarter", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-10-01 04:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Quarter", "UTC").utc.to_s).to eq("2010-10-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("Last Quarter", "UTC", "end").utc.to_s).to eq("2010-12-31 23:59:59 UTC")

        # Test This ...
        expect(MiqExpression.normalize_date_time("This Hour", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Hour", "UTC").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Hour", "UTC", "end").utc.to_s).to eq("2011-01-11 17:59:59 UTC")

        expect(MiqExpression.normalize_date_time("This Week", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-10 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Week", "UTC").utc.to_s).to eq("2011-01-10 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Week", "UTC", "end").utc.to_s).to eq("2011-01-16 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("This Month", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-01 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Month", "UTC").utc.to_s).to eq("2011-01-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Month", "UTC", "end").utc.to_s).to eq("2011-01-31 23:59:59 UTC")

        expect(MiqExpression.normalize_date_time("This Quarter", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-01 05:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Quarter", "UTC").utc.to_s).to eq("2011-01-01 00:00:00 UTC")
        expect(MiqExpression.normalize_date_time("This Quarter", "UTC", "end").utc.to_s).to eq("2011-03-31 23:59:59 UTC")
      end

      it "should generate the correct ruby expression running to_ruby with an expression having relative dates with no time zone" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-09'.to_date")

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-09T23:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-09'.to_date")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time < '2011-01-09T00:00:00Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T16:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T17:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-09T23:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2010-11-01T00:00:00Z'.to_time(:utc) && val.to_time <= '2010-12-31T23:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-09T23:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Last Week"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T14:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T14:59:59Z'.to_time(:utc)")
      end

      it "should generate the correct ruby expression running to_ruby with an expression having relative time with a time zone" do
        tz = "Hawaii"

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T16:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T17:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T09:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2010-11-01T10:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-01T09:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T09:59:59Z'.to_time(:utc)")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Last Week"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T14:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T14:59:59Z'.to_time(:utc)")
      end

      it "should generate the correct SQL query running to_sql with an expression having relative dates with no time zone" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on > '2011-01-09'")

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on > '2011-01-09T23:59:59Z'")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on < '2011-01-09'")

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on < '2011-01-09T00:00:00Z'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on BETWEEN '2011-01-11T16:00:00Z' AND '2011-01-11T17:59:59Z'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on BETWEEN '2011-01-03' AND '2011-01-09'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on BETWEEN '2011-01-03T00:00:00Z' AND '2011-01-09T23:59:59Z'")

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on BETWEEN '2010-11-01T00:00:00Z' AND '2010-12-31T23:59:59Z'")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on BETWEEN '2011-01-11' AND '2011-01-11'")

        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.retires_on BETWEEN '2011-01-11' AND '2011-01-11'")

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        sql, includes, attrs = exp.to_sql
        expect(sql).to eq("vms.last_scan_on BETWEEN '2011-01-11T14:00:00Z' AND '2011-01-11T14:59:59Z'")
      end

      it "should generate the correct human expression running to_ruby with an expression having relative dates with no time zone" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        expect(exp.to_human).to eq('VM and Instance : Retires On AFTER "2 Days Ago"')

        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time AFTER "2 Days Ago"')

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        expect(exp.to_human).to eq('VM and Instance : Retires On BEFORE "2 Days Ago"')

        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time BEFORE "2 Days Ago"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "Last Hour" THROUGH "This Hour"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_human).to eq('VM and Instance : Retires On FROM "Last Week" THROUGH "Last Week"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "Last Week" THROUGH "Last Week"')

        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "2 Months Ago" THROUGH "Last Month"')

        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time IS "3 Hours Ago"')
      end
    end
  end

  context "Alias support in to human conversions" do
    context "should handle expression atoms that do/don't have alias keys" do
      it "FIELD type" do
        exp = MiqExpression.new(">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes"})
        expect(exp.to_human).to eq('VM and Instance : Allocated Disk Storage > 5 MB')

        exp = MiqExpression.new(">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes", "alias" => "Disk"})
        expect(exp.to_human).to eq('Disk > 5 MB')
      end

      it "FIND/CHECK type" do
        exp = MiqExpression.new("FIND" => {"search" => {"STARTS WITH" => {"field" => "Vm.advanced_settings-name", "value" => "X"}}, "checkall" => {"=" => {"field" => "Vm.advanced_settings-read_only", "value" => "true"}}})
        expect(exp.to_human).to eq('FIND VM and Instance.Advanced Settings : Name STARTS WITH "X" CHECK ALL Read Only = "true"')

        exp = MiqExpression.new({"FIND" => {"search" => {"STARTS WITH" => {"field" => "Vm.advanced_settings-name", "value" => "X", "alias" => "Settings Name"}}, "checkall" => {"=" => {"field" => "Vm.advanced_settings-read_only", "value" => "true"}}}})
        expect(exp.to_human).to eq('FIND Settings Name STARTS WITH "X" CHECK ALL Read Only = "true"')
      end

      it "COUNT type" do
        exp = MiqExpression.new({">" => {"count" => "Vm.snapshots", "value" => "1"}})
        expect(exp.to_human).to eq("COUNT OF VM and Instance.Snapshots > 1")

        exp = MiqExpression.new(">" => {"count" => "Vm.snapshots", "value" => "1", "alias" => "Snaps"})
        expect(exp.to_human).to eq("COUNT OF Snaps > 1")
      end

      it "TAG type" do
        # tags contain the root tenant's name
        Tenant.seed

        category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
        FactoryGirl.create(:classification, :parent_id => category.id, :name => 'prod', :description => 'Production')

        exp = MiqExpression.new("CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod"})
        expect(exp.to_human).to eq("Host / Node.My Company Tags : Environment CONTAINS 'Production'")

        exp = MiqExpression.new("CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod", "alias" => "Env"})
        expect(exp.to_human).to eq("Env CONTAINS 'Production'")
      end
    end
  end

  it "should test virtual column FB15509" do
    exp = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      CONTAINS:
        field: MiqGroup.vms-disconnected
        value: "false"
    '

    sql, incl, attrs = exp.to_sql
    expect(attrs[:supported_by_sql]).to eq(false)
  end

  describe ".quick_search?" do
    it "detects false in hash" do
      expect(MiqExpression.quick_search?(exp)).to be_falsey
    end

    it "detects in hash" do
      expect(MiqExpression.quick_search?(qs_exp)).to be_truthy
    end

    it "detects in complex hash" do
      expect(MiqExpression.quick_search?(complex_qs_exp)).to be_truthy
    end

    it "detects false in miq expression" do
      expect(MiqExpression.quick_search?(MiqExpression.new(exp))).to be_falsey
    end

    it "detects in miq expression" do
      expect(MiqExpression.quick_search?(MiqExpression.new(qs_exp))).to be_truthy
    end
  end

  describe "#quick_search?" do
    it "detects false in hash" do
      expect(MiqExpression.new(exp).quick_search?).to be_falsey
    end

    it "detects in hash" do
      expect(MiqExpression.new(qs_exp).quick_search?).to be_truthy
    end

    it "detects in complex hash" do
      expect(MiqExpression.new(complex_qs_exp).quick_search?).to be_truthy
    end
  end

  describe ".merge_where_clauses" do
    it "returns nil for nil" do
      expect(MiqExpression.merge_where_clauses(nil)).to be_nil
    end

    it "returns nil for blank" do
      expect(MiqExpression.merge_where_clauses("")).to be_nil
    end

    it "returns nil for multiple empty arrays" do
      expect(MiqExpression.merge_where_clauses([],[])).to be_nil
    end

    it "returns same string single results" do
      expect(MiqExpression.merge_where_clauses("a=5")).to eq("a=5")
    end

    it "returns same string when concatinating blank results" do
      expect(MiqExpression.merge_where_clauses("a=5", [])).to eq("a=5")
    end

    # would be nice if we returned a hash
    it "returns a string if the only argument is a hash" do
      expect(MiqExpression.merge_where_clauses({"vms.id" => 5})).to eq("\"vms\".\"id\" = 5")
    end

    it "concatinates 2 arrays" do
      expect(MiqExpression.merge_where_clauses(["a=?",5], ["b=?",5])).to eq("(a=5) AND (b=5)")
    end

    it "concatinates 2 string" do
      expect(MiqExpression.merge_where_clauses("a=5", "b=5")).to eq("(a=5) AND (b=5)")
    end

    it "concatinates a string and a hash" do
      expect(MiqExpression.merge_where_clauses("a=5", {"vms.id" => 5})).to eq("(a=5) AND (\"vms\".\"id\" = 5)")
    end
  end
end
