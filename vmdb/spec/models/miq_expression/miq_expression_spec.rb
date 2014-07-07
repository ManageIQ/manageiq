require "spec_helper"

describe MiqExpression do
  before(:each) do
    # Create a single host and vm for searching
    @host = FactoryGirl.create(:host)
    @host.filesystems << FactoryGirl.create(:filesystem)
    @host.save

    @vm   = FactoryGirl.create(:vm_vmware)
  end

  # Based on FogBugz 6181: something INCLUDES []
  it "should test bracket characters" do
    exp    = MiqExpression.new({"INCLUDES"=>{"field"=>"Vm-name", "value"=>"/[]/"}})
    # puts "Expression in Human: #{exp.to_human}"
    # puts "Expression in SQL:   #{exp.to_sql}"
    clause = exp.to_ruby
    # puts "Expression in Ruby:  #{clause}"
    # puts
  end

  it "should test numeric set expressions" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      "=":
        field: Host-enabled_inbound_ports
        value: "22,427,5988,5989"
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == '<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> == [22,427,5988,5989]'

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ALL:
        field: Host-enabled_inbound_ports
        value: 22, 427, 5988, 5989, 1..4
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == '(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> & [1,2,3,4,22,427,5988,5989]) == [1,2,3,4,22,427,5988,5989]'

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ANY:
        field: Host-enabled_inbound_ports
        value: 22, 427, 5988, 5989, 1..3
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == '([1,2,3,22,427,5988,5989] - <value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value>) != [1,2,3,22,427,5988,5989]'

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      INCLUDES ONLY:
        field: Host-enabled_inbound_ports
        value: 22
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == '(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [22]) == []'

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      LIMITED TO:
        field: Host-enabled_inbound_ports
        value: 22
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == '(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [22]) == []'
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
    filter.to_ruby.should == "<value ref=host, type=string_set>/virtual/service_names</value> == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']"

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
    filter.to_ruby.should == "(<value ref=host, type=string_set>/virtual/service_names</value> & ['ntpd','sshd','vmware-vpxa','vmware-webAccess']) == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']"

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
    filter.to_ruby.should == "(['ntpd','sshd','vmware-vpxa','vmware-webAccess'] - <value ref=host, type=string_set>/virtual/service_names</value>) != ['ntpd','sshd','vmware-vpxa','vmware-webAccess']"

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
    filter.to_ruby.should == "(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []"

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
    filter.to_ruby.should == "(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []"

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
    filter.to_ruby.should == "<find><search><value ref=host, type=text>/virtual/filesystems/name</value> == '/etc/passwd'</search><check mode=all><value ref=host, type=string>/virtual/filesystems/permissions</value> == '0644'</check></find>"
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
    filter.to_ruby.should == '<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/'

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
    filter.to_ruby.should == '<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/'

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
    filter.to_ruby.should == '<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == \'true\'</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> =~ /^.*SLP.*$/</check></find>'

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
    filter.to_ruby.should == '<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == \'true\'</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> !~ /^.*SLP.*$/</check></find>'
  end

  it "should test ruby" do
    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      FIND:
        search:
          "=":
            field: Host.filesystems-name
            value: /etc/shadow
        checkall:
          RUBY:
            field: Host.filesystems-contents
            value: |
                # $log.info("Testing") # Needs $SAFE=1
                return result if context.blank?

                lines = context.split("\n")
                lines.each do |l|
                  d0, d1, d3, d4, pwdlife = l.split(":")
                  if pwdlife.to_i > 90
                    # puts "Failed: pwdlife: #{pwdlife}, Line: #{l}" # Needs $SAFE <= 3
                    log "Failed: pwdlife: #{pwdlife}, Line: #{l}"
                    return false
                  end
                end
    '

    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      RUBY:
        field: Host-name
        value: |
            log("Testing: Context: [#{context.inspect}]")
            return context == "VI4ESX7.galaxy.local"
    '

    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      RUBY:
        field: Host-name
        value: |
            log("Testing: Context: [#{context.inspect}]")
            return 500
    '

    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    lambda { Rbac.search(:class => Host, :filter => filter) }.should raise_error(RuntimeError, "Expected return value of true or false from ruby script but instead got result: [500]")
    # puts

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      FIND:
        search:
          RUBY:
            field: Host.filesystems-name
            value: |
                log "XXX Hello, context: #{context.inspect}"; context=="/etc/shadow"
        checkall:
          IS NOT NULL:
            field: Host.filesystems-mtime
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == "<find><search>__start_ruby__ __start_context__<value ref=host, type=raw>/virtual/filesystems/name</value>__type__text__end_context__ __start_script__log \"XXX Hello, context: \#{context.inspect}\"; context==\"/etc/shadow\"\n__end_script__ __end_ruby__</search><check mode=all><value ref=host, type=datetime>/virtual/filesystems/mtime</value> != nil</check></find>"

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      RUBY:
        field: Host-v_total_vms
        value: |
            return context <= 7
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == "__start_ruby__ __start_context__<value ref=host, type=raw>/virtual/v_total_vms</value>__type__integer__end_context__ __start_script__return context <= 7\n__end_script__ __end_ruby__"
  end

  it "should test error handling" do
    pending "This test occasionally fails for no apparent reason"

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      RUBY:
        field: Host.name
        value: |
            log("Testing: Context: [#{context}]")
            raise "Bang!"
            return true
    '

    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    lambda { Rbac.search(:class => Host, :filter => filter) }.should raise_error(RuntimeError, "Ruby script raised error [(eval):3:in `_eval': Bang!]")
    # puts

    filter = YAML.load '--- !ruby/object:MiqExpression
    exp:
      FIND:
        search:
          RUBY:
            field: Host.filesystems-name
            value: |
                sleep 21
                return true
        checkall:
          IS NOT NULL:
            field: Host.filesystems-mtime
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    lambda { Rbac.search(:class => Host, :filter => filter) }.should raise_error(RuntimeError, "Ruby script timed out after 20 seconds")
    # puts
  end

  it "should test fb7726" do
    filter =  YAML.load '--- !ruby/object:MiqExpression
    exp:
      CONTAINS:
        field: Host.filesystems-name
        value: /etc/shadow
    '
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"
    # puts
    filter.to_ruby.should == "<exist ref=host>/virtual/filesystems/name/%2fetc%2fshadow</exist>"
  end

  it "should test context hash" do
    data = {"name"=>"VM_1", "guest_applications.version"=>"3.1.2.7193", "guest_applications.release"=>nil, "guest_applications.vendor"=>"VMware, Inc.", "id"=>9, "guest_applications.name"=>"VMware Tools", "guest_applications.package_name"=>nil}

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
    filter.to_ruby.should == "<value type=string>guest_applications.name</value> == 'VMware Tools'"
    Condition.subst(filter.to_ruby, data, {}).should == "'VMware Tools' == 'VMware Tools'"

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
    filter.to_ruby.should == "<value type=string>guest_applications.vendor</value> =~ /^[^.]*ware.*$/"
    Condition.subst(filter.to_ruby, data, {}).should == "'VMware, Inc.' =~ /^[^.]*ware.*$/"
  end

  it "should test atom error" do
    MiqExpression.atom_error("Host-xx", "regular expression matches", '123[)').should_not be_false

    MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '').should_not be_false
    MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '123abc').should_not be_false
    MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '123').should be_false
    MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '123.456').should be_false
    MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "=", '2,123.456').should be_false

    MiqExpression.atom_error("Vm-cpu_limit", "=", '').should_not be_false
    MiqExpression.atom_error("Vm-cpu_limit", "=", '123.5').should_not be_false
    MiqExpression.atom_error("Vm-cpu_limit", "=", '123.5.abc').should_not be_false
    MiqExpression.atom_error("Vm-cpu_limit", "=", '123').should be_false
    MiqExpression.atom_error("Vm-cpu_limit", "=", '2,123').should be_false

    MiqExpression.atom_error("Vm-created_on", "=", Time.now.to_s).should be_false
    MiqExpression.atom_error("Vm-created_on", "=", "123456").should_not be_false
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
    filter.to_ruby.should == '<value ref=vm, type=integer>/virtual/memory_shares</value> >= 25600'

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
    filter.to_ruby.should == '<value ref=vm, type=integer>/virtual/used_disk_storage</value> >= 1048576000'
  end

  context "._model_details" do
    it "should not be overly aggressive in filtering out columns for logical CPUs" do
      relats  = MiqExpression.get_relats(Vm)
      details = MiqExpression._model_details(relats, {})
      cluster_sorted = details.select { |d| d.first.starts_with?("Cluster") }.sort
      cluster_sorted.select { |d| d.first == "Cluster : Total Number of Physical CPUs" }.should_not be_empty
      cluster_sorted.select { |d| d.first == "Cluster : Total Number of Logical CPUs" }.should_not be_empty
      hardware_sorted = details.select { |d| d.first.starts_with?("Hardware") }.sort
      hardware_sorted.select { |d| d.first == "Hardware : Logical Cpus" }.should be_empty
    end
  end

  context "Date/Time Support" do
    context "Testing expression conversion ruby, sql and human with static dates and times" do
      it "should generate the correct ruby expression with an expression having static dates and times with no time zone" do
        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time > '2011-01-10T23:59:59Z'.to_time"

        exp = MiqExpression.new({">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time > '2011-01-10T23:59:59Z'.to_time"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time < '2011-01-10T00:00:00Z'.to_time"

        exp = MiqExpression.new({"<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time < '2011-01-10T00:00:00Z'.to_time"

        exp = MiqExpression.new({">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time"

        exp = MiqExpression.new({"<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time <= '2011-01-10T23:59:59Z'.to_time"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T09:00:00Z'.to_time"

        exp = MiqExpression.new({">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T09:00:00Z'.to_time"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date == '2011-01-10'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time && val.to_time <= '2011-01-10T23:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-09T00:00:00Z'.to_time && val.to_time <= '2011-01-10T23:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-09T00:00:00Z'.to_time && val.to_time <= '2011-01-10T23:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T08:00:00Z'.to_time && val.to_time <= '2011-01-10T17:00:00Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time && val.to_time <= '2011-01-10T00:00:00Z'.to_time"
      end

      it "should generate the correct ruby expression running to_ruby with an expression having static dates and times with a time zone" do
        tz = "Eastern Time (US & Canada)"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time > '2011-01-11T04:59:59Z'.to_time"

        exp = MiqExpression.new({">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time > '2011-01-11T04:59:59Z'.to_time"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time < '2011-01-10T05:00:00Z'.to_time"

        exp = MiqExpression.new({"<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time < '2011-01-10T05:00:00Z'.to_time"

        exp = MiqExpression.new({">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-10T05:00:00Z'.to_time"

        exp = MiqExpression.new({"<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time <= '2011-01-11T04:59:59Z'.to_time"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T14:00:00Z'.to_time"

        exp = MiqExpression.new({">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T14:00:00Z'.to_time"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date == '2011-01-10'.to_date"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-09T05:00:00Z'.to_time && val.to_time <= '2011-01-11T04:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T13:00:00Z'.to_time && val.to_time <= '2011-01-10T22:00:00Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T05:00:00Z'.to_time && val.to_time <= '2011-01-10T05:00:00Z'.to_time"
      end

      it "should generate the correct SQL query running to_sql with an expression having static dates and times with no time zone" do
        sqlserver = ActiveRecord::Base.connection.adapter_name == "SQLServer"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on > #{'N' if sqlserver}'2011-01-10T23:59:59Z'"

        exp = MiqExpression.new({">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on > #{'N' if sqlserver}'2011-01-10T23:59:59Z'"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on < #{'N' if sqlserver}'2011-01-10T00:00:00Z'"

        exp = MiqExpression.new({"<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on < #{'N' if sqlserver}'2011-01-10T00:00:00Z'"

        exp = MiqExpression.new({">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on >= #{'N' if sqlserver}'2011-01-10T00:00:00Z'"

        exp = MiqExpression.new({"<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on <= #{'N' if sqlserver}'2011-01-10T23:59:59Z'"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on > #{'N' if sqlserver}'2011-01-10T09:00:00Z'"

        exp = MiqExpression.new({">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on > #{'N' if sqlserver}'2011-01-10T09:00:00Z'"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on = '#{sqlserver ? "01-10-2011" : "2011-01-10"}'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on BETWEEN #{'N' if sqlserver}'2011-01-09T00:00:00Z' AND #{'N' if sqlserver}'2011-01-10T23:59:59Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on BETWEEN #{'N' if sqlserver}'2011-01-09T00:00:00Z' AND #{'N' if sqlserver}'2011-01-10T23:59:59Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on BETWEEN #{'N' if sqlserver}'2011-01-10T08:00:00Z' AND #{'N' if sqlserver}'2011-01-10T17:00:00Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on BETWEEN #{'N' if sqlserver}'2011-01-10T00:00:00Z' AND #{'N' if sqlserver}'2011-01-10T00:00:00Z'"
      end

      it "should generate the correct human expression with an expression having static dates and times with no time zone" do
        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On AFTER "2011-01-10"'

        exp = MiqExpression.new({">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On > "2011-01-10"'

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On BEFORE "2011-01-10"'

        exp = MiqExpression.new({"<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On < "2011-01-10"'

        exp = MiqExpression.new({">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On >= "2011-01-10"'

        exp = MiqExpression.new({"<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On <= "2011-01-10"'

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time AFTER "2011-01-10 9:00"'

        exp = MiqExpression.new({">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time > "2011-01-10 9:00"'

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}})
        exp.to_human.should == 'VM and Instance : Retires On IS "2011-01-10"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]}})
        exp.to_human.should == 'VM and Instance : Retires On FROM "2011-01-09" THROUGH "2011-01-10"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]}})
        exp.to_human.should == 'VM and Instance : Retires On FROM "01/09/2011" THROUGH "01/10/2011"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time FROM "2011-01-10 8:00" THROUGH "2011-01-10 17:00"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time FROM "2011-01-10 00:00" THROUGH "2011-01-10 00:00"'
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
        MiqExpression.normalize_date_time("3 Hours Ago", "Eastern Time (US & Canada)"   ).utc.to_s.should == "2011-01-11 14:00:00 UTC"
        MiqExpression.normalize_date_time("3 Hours Ago", "UTC"                          ).utc.to_s.should == "2011-01-11 14:00:00 UTC"
        MiqExpression.normalize_date_time("3 Hours Ago", "UTC", "end"                   ).utc.to_s.should == "2011-01-11 14:59:59 UTC"

        MiqExpression.normalize_date_time("3 Days Ago", "Eastern Time (US & Canada)"    ).utc.to_s.should == "2011-01-08 05:00:00 UTC"
        MiqExpression.normalize_date_time("3 Days Ago", "UTC"                           ).utc.to_s.should == "2011-01-08 00:00:00 UTC"
        MiqExpression.normalize_date_time("3 Days Ago", "UTC", "end"                    ).utc.to_s.should == "2011-01-08 23:59:59 UTC"

        MiqExpression.normalize_date_time("3 Weeks Ago", "Eastern Time (US & Canada)"   ).utc.to_s.should == "2010-12-20 05:00:00 UTC"
        MiqExpression.normalize_date_time("3 Weeks Ago", "UTC"                          ).utc.to_s.should == "2010-12-20 00:00:00 UTC"

        MiqExpression.normalize_date_time("4 Months Ago", "Eastern Time (US & Canada)"  ).utc.to_s.should == "2010-09-01 04:00:00 UTC"
        MiqExpression.normalize_date_time("4 Months Ago", "UTC"                         ).utc.to_s.should == "2010-09-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("4 Months Ago", "UTC", "end"                  ).utc.to_s.should == "2010-09-30 23:59:59 UTC"

        MiqExpression.normalize_date_time("1 Quarter Ago", "Eastern Time (US & Canada)" ).utc.to_s.should == "2010-10-01 04:00:00 UTC"
        MiqExpression.normalize_date_time("1 Quarter Ago", "UTC"                        ).utc.to_s.should == "2010-10-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("1 Quarter Ago", "UTC", "end"                 ).utc.to_s.should == "2010-12-31 23:59:59 UTC"

        MiqExpression.normalize_date_time("3 Quarters Ago", "Eastern Time (US & Canada)").utc.to_s.should == "2010-04-01 04:00:00 UTC"
        MiqExpression.normalize_date_time("3 Quarters Ago", "UTC"                       ).utc.to_s.should == "2010-04-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("3 Quarters Ago", "UTC", "end"                ).utc.to_s.should == "2010-06-30 23:59:59 UTC"

        # Test Now, Today, Yesterday
        MiqExpression.normalize_date_time("Now", "Eastern Time (US & Canada)"           ).utc.to_s.should == "2011-01-11 17:00:00 UTC"
        MiqExpression.normalize_date_time("Now", "UTC"                                  ).utc.to_s.should == "2011-01-11 17:00:00 UTC"
        MiqExpression.normalize_date_time("Now", "UTC", "end"                           ).utc.to_s.should == "2011-01-11 17:59:59 UTC"

        MiqExpression.normalize_date_time("Today", "Eastern Time (US & Canada)"         ).utc.to_s.should == "2011-01-11 05:00:00 UTC"
        MiqExpression.normalize_date_time("Today", "UTC"                                ).utc.to_s.should == "2011-01-11 00:00:00 UTC"
        MiqExpression.normalize_date_time("Today", "UTC", "end"                         ).utc.to_s.should == "2011-01-11 23:59:59 UTC"

        MiqExpression.normalize_date_time("Yesterday", "Eastern Time (US & Canada)"     ).utc.to_s.should == "2011-01-10 05:00:00 UTC"
        MiqExpression.normalize_date_time("Yesterday", "UTC"                            ).utc.to_s.should == "2011-01-10 00:00:00 UTC"
        MiqExpression.normalize_date_time("Yesterday", "UTC", "end"                     ).utc.to_s.should == "2011-01-10 23:59:59 UTC"

        # Test Last ...
        MiqExpression.normalize_date_time("Last Hour", "Eastern Time (US & Canada)"     ).utc.to_s.should == "2011-01-11 16:00:00 UTC"
        MiqExpression.normalize_date_time("Last Hour", "UTC"                            ).utc.to_s.should == "2011-01-11 16:00:00 UTC"
        MiqExpression.normalize_date_time("Last Hour", "UTC", "end"                     ).utc.to_s.should == "2011-01-11 16:59:59 UTC"

        MiqExpression.normalize_date_time("Last Week", "Eastern Time (US & Canada)"     ).utc.to_s.should == "2011-01-03 05:00:00 UTC"
        MiqExpression.normalize_date_time("Last Week", "UTC"                            ).utc.to_s.should == "2011-01-03 00:00:00 UTC"
        MiqExpression.normalize_date_time("Last Week", "UTC", "end"                     ).utc.to_s.should == "2011-01-09 23:59:59 UTC"

        MiqExpression.normalize_date_time("Last Month", "Eastern Time (US & Canada)"    ).utc.to_s.should == "2010-12-01 05:00:00 UTC"
        MiqExpression.normalize_date_time("Last Month", "UTC"                           ).utc.to_s.should == "2010-12-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("Last Month", "UTC", "end"                    ).utc.to_s.should == "2010-12-31 23:59:59 UTC"

        MiqExpression.normalize_date_time("Last Quarter", "Eastern Time (US & Canada)"  ).utc.to_s.should == "2010-10-01 04:00:00 UTC"
        MiqExpression.normalize_date_time("Last Quarter", "UTC"                         ).utc.to_s.should == "2010-10-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("Last Quarter", "UTC", "end"                  ).utc.to_s.should == "2010-12-31 23:59:59 UTC"

        # Test This ...
        MiqExpression.normalize_date_time("This Hour", "Eastern Time (US & Canada)"     ).utc.to_s.should == "2011-01-11 17:00:00 UTC"
        MiqExpression.normalize_date_time("This Hour", "UTC"                            ).utc.to_s.should == "2011-01-11 17:00:00 UTC"
        MiqExpression.normalize_date_time("This Hour", "UTC", "end"                     ).utc.to_s.should == "2011-01-11 17:59:59 UTC"

        MiqExpression.normalize_date_time("This Week", "Eastern Time (US & Canada)"     ).utc.to_s.should == "2011-01-10 05:00:00 UTC"
        MiqExpression.normalize_date_time("This Week", "UTC"                            ).utc.to_s.should == "2011-01-10 00:00:00 UTC"
        MiqExpression.normalize_date_time("This Week", "UTC", "end"                     ).utc.to_s.should == "2011-01-16 23:59:59 UTC"

        MiqExpression.normalize_date_time("This Month", "Eastern Time (US & Canada)"    ).utc.to_s.should == "2011-01-01 05:00:00 UTC"
        MiqExpression.normalize_date_time("This Month", "UTC"                           ).utc.to_s.should == "2011-01-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("This Month", "UTC", "end"                    ).utc.to_s.should == "2011-01-31 23:59:59 UTC"

        MiqExpression.normalize_date_time("This Quarter", "Eastern Time (US & Canada)"  ).utc.to_s.should == "2011-01-01 05:00:00 UTC"
        MiqExpression.normalize_date_time("This Quarter", "UTC"                         ).utc.to_s.should == "2011-01-01 00:00:00 UTC"
        MiqExpression.normalize_date_time("This Quarter", "UTC", "end"                  ).utc.to_s.should == "2011-03-31 23:59:59 UTC"
      end

      it "should generate the correct ruby expression running to_ruby with an expression having relative dates with no time zone" do
        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time > '2011-01-09T23:59:59Z'.to_time"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-09T23:59:59Z'.to_time"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time < '2011-01-09T00:00:00Z'.to_time"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time < '2011-01-09T00:00:00Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T16:00:00Z'.to_time && val.to_time <= '2011-01-11T17:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time && val.to_time <= '2011-01-09T23:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time && val.to_time <= '2011-01-09T23:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2010-11-01T00:00:00Z'.to_time && val.to_time <= '2010-12-31T23:59:59Z'.to_time"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time && val.to_time <= '2011-01-09T23:59:59Z'.to_time"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "Last Week"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "Today"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"}})
        exp.to_ruby.should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"}})
        exp.to_ruby.should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T14:00:00Z'.to_time && val.to_time <= '2011-01-11T14:59:59Z'.to_time"
      end

      it "should generate the correct ruby expression running to_ruby with an expression having relative time with a time zone" do
        tz = "Hawaii"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T16:00:00Z'.to_time && val.to_time <= '2011-01-11T17:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time && val.to_time <= '2011-01-10T09:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time && val.to_time <= '2011-01-10T09:59:59Z'.to_time"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2010-11-01T10:00:00Z'.to_time && val.to_time <= '2011-01-01T09:59:59Z'.to_time"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time && val.to_time <= '2011-01-10T09:59:59Z'.to_time"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "Last Week"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "Today"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"}})
        exp.to_ruby(tz).should == "val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T14:00:00Z'.to_time && val.to_time <= '2011-01-11T14:59:59Z'.to_time"
      end

      it "should generate the correct SQL query running to_sql with an expression having relative dates with no time zone" do
        sqlserver = ActiveRecord::Base.connection.adapter_name == "SQLServer"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on > #{'N' if sqlserver}'2011-01-09T23:59:59Z'"

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on > #{'N' if sqlserver}'2011-01-09T23:59:59Z'"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on < #{'N' if sqlserver}'2011-01-09T00:00:00Z'"

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on < #{'N' if sqlserver}'2011-01-09T00:00:00Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on BETWEEN #{'N' if sqlserver}'2011-01-11T16:00:00Z' AND #{'N' if sqlserver}'2011-01-11T17:59:59Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on BETWEEN #{'N' if sqlserver}'2011-01-03T00:00:00Z' AND #{'N' if sqlserver}'2011-01-09T23:59:59Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on BETWEEN #{'N' if sqlserver}'2011-01-03T00:00:00Z' AND #{'N' if sqlserver}'2011-01-09T23:59:59Z'"

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on BETWEEN #{'N' if sqlserver}'2010-11-01T00:00:00Z' AND #{'N' if sqlserver}'2010-12-31T23:59:59Z'"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "Today"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on BETWEEN '#{sqlserver ? "01-11-2011" : "2011-01-11"}' AND '#{sqlserver ? "01-11-2011" : "2011-01-11"}'"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.retires_on BETWEEN '#{sqlserver ? "01-11-2011" : "2011-01-11"}' AND '#{sqlserver ? "01-11-2011" : "2011-01-11"}'"

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"}})
        sql, includes, attrs = exp.to_sql
        sql.should == "vms.last_scan_on BETWEEN #{'N' if sqlserver}'2011-01-11T14:00:00Z' AND #{'N' if sqlserver}'2011-01-11T14:59:59Z'"
      end

      it "should generate the correct human expression running to_ruby with an expression having relative dates with no time zone" do
        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"}})
        exp.to_human.should == 'VM and Instance : Retires On AFTER "2 Days Ago"'

        exp = MiqExpression.new({"AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time AFTER "2 Days Ago"'

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"}})
        exp.to_human.should == 'VM and Instance : Retires On BEFORE "2 Days Ago"'

        exp = MiqExpression.new({"BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time BEFORE "2 Days Ago"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time FROM "Last Hour" THROUGH "This Hour"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]}})
        exp.to_human.should == 'VM and Instance : Retires On FROM "Last Week" THROUGH "Last Week"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time FROM "Last Week" THROUGH "Last Week"'

        exp = MiqExpression.new({"FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time FROM "2 Months Ago" THROUGH "Last Month"'

        exp = MiqExpression.new({"IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"}})
        exp.to_human.should == 'VM and Instance : Last Analysis Time IS "3 Hours Ago"'
      end
    end

  end

  context "Alias support in to human conversions" do
    context "should handle expression atoms that do/don't have alias keys" do
      it "FIELD type" do
        exp = MiqExpression.new({">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes"}})
        exp.to_human.should == 'VM and Instance : Allocated Disk Storage > 5 MB'

        exp = MiqExpression.new({">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes", "alias" => "Disk"}})
        exp.to_human.should == 'Disk > 5 MB'
      end

      it "FIND/CHECK type" do
        exp = MiqExpression.new({"FIND" => {"search" => {"STARTS WITH" => {"field" => "Vm.advanced_settings-name", "value" => "X"}}, "checkall" => {"=" => {"field" => "Vm.advanced_settings-read_only", "value" => "true"}}}})
        exp.to_human.should == "FIND VM and Instance.Advanced Settings : Name STARTS WITH \"X\" CHECK ALL Read Only = 'true'"

        exp = MiqExpression.new({"FIND" => {"search" => {"STARTS WITH" => {"field" => "Vm.advanced_settings-name", "value" => "X", "alias" => "Settings Name"}}, "checkall" => {"=" => {"field" => "Vm.advanced_settings-read_only", "value" => "true"}}}})
        exp.to_human.should == "FIND Settings Name STARTS WITH \"X\" CHECK ALL Read Only = 'true'"
      end

      it "COUNT type" do
        exp = MiqExpression.new({">" => {"count" => "Vm.snapshots", "value" => "1"}})
        exp.to_human.should == "COUNT OF VM and Instance.Snapshots > 1"

        exp = MiqExpression.new({">" => {"count" => "Vm.snapshots", "value" => "1", "alias" => "Snaps"}})
        exp.to_human.should == "COUNT OF Snaps > 1"
      end

      it "TAG type" do
        # Create tag category and tag for the next 2 tests
        category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
        FactoryGirl.create(:classification, :parent_id => category.id, :name => 'prod', :description => 'Production')

        exp = MiqExpression.new({"CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod"}})
        exp.to_human.should == "Host.My Company Tags : Environment CONTAINS 'Production'"

        exp = MiqExpression.new({"CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod", "alias" => "Env"}})
        exp.to_human.should == "Env CONTAINS 'Production'"
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
    attrs[:supported_by_sql].should == false
  end

  context "Testing quick_search? methods" do
    before :each do
      @exp = {"=" => {"field" => "Vm-name", "value" => "test"}}
      @qs_exp = {"=" => {"field" => "Vm-name", "value" => :user_input}}
      @complex_qs_exp = {"AND" => [{"=" => { "field" => "Vm-name", "value" => "test"}}, {"=" => {"field" => "Vm-name", "value" => :user_input}}]}
    end

    context "calling class method with array/hash" do
      it "should return false if not a quick search" do
        MiqExpression.quick_search?(@exp).should be_false
      end
      it "should return true if a quick search" do
        MiqExpression.quick_search?(@qs_exp).should be_true
      end
      it "should return true if a complex quick search" do
        MiqExpression.quick_search?(@complex_qs_exp).should be_true
      end
    end

    context "calling class method with MiqExpression object" do
      it "should return false if not a quick search" do
        MiqExpression.quick_search?(MiqExpression.new(@exp)).should be_false
      end
      it "should return true if a quick search" do
        MiqExpression.quick_search?(MiqExpression.new(@qs_exp)).should be_true
      end
      it "should return true if a complex quick search" do
        MiqExpression.quick_search?(MiqExpression.new(@complex_qs_exp)).should be_true
      end
    end

    context "calling instance method" do
      it "should return false if not a quick search" do
        MiqExpression.new(@exp).quick_search?.should be_false
      end
      it "should return true if a quick search" do
        MiqExpression.new(@qs_exp).quick_search?.should be_true
      end
      it "should return true if a complex quick search" do
        MiqExpression.new(@complex_qs_exp).quick_search?.should be_true
      end
    end

  end
end
