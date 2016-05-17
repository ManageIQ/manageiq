describe MiqExpression do

  describe "#to_sql" do
    it "generates the SQL for an EQUAL expression" do
      sql, * = MiqExpression.new("EQUAL" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" = 'foo'")
    end

    it "generates the SQL for an EQUAL expression with an association" do
      exp = {"EQUAL" => {"field" => "Vm.guest_applications-name", "value" => 'foo'}}
      sql, includes, * = MiqExpression.new(exp).to_sql
      expect(sql).to eq("\"guest_applications\".\"name\" = 'foo'")
      expect(includes).to eq(:guest_applications => {})
    end

    it "generates the SQL for a = expression" do
      sql, * = MiqExpression.new("=" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" = 'foo'")
    end

    it "generates the SQL for a < expression" do
      sql, * = described_class.new("<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" < 2")
    end

    it "generates the SQL for a <= expression" do
      sql, * = described_class.new("<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" <= 2")
    end

    it "generates the SQL for a > expression" do
      sql, * = described_class.new(">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" > 2")
    end

    it "generates the SQL for a >= expression" do
      sql, * = described_class.new(">=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" >= 2")
    end

    it "generates the SQL for a != expression" do
      sql, * = described_class.new("!=" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" != 'foo'")
    end

    it "generates the SQL for a LIKE expression" do
      sql, * = MiqExpression.new("LIKE" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" LIKE '%foo%'")
    end

    it "generates the SQL for a NOT LIKE expression" do
      sql, * = MiqExpression.new("NOT LIKE" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" NOT LIKE '%foo%'")
    end

    it "generates the SQL for a STARTS WITH expression " do
      sql, * = MiqExpression.new("STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" LIKE 'foo%'")
    end

    it "generates the SQL for an ENDS WITH expression" do
      sql, * = MiqExpression.new("ENDS WITH" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" LIKE '%foo'")
    end

    it "generates the SQL for an INCLUDES" do
      sql, * = MiqExpression.new("INCLUDES" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" LIKE '%foo%'")
    end

    it "generates the SQL for an AND expression" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-name", "value" => "bar"}}
      sql, * = MiqExpression.new("AND" => [exp1, exp2]).to_sql
      expect(sql).to eq("(\"vms\".\"name\" LIKE 'foo%' AND \"vms\".\"name\" LIKE '%bar')")
    end

    it "generates the SQL for an AND expression where only one is supported by SQL" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-platform", "value" => "bar"}}
      sql, * = MiqExpression.new("AND" => [exp1, exp2]).to_sql
      expect(sql).to eq("(\"vms\".\"name\" LIKE 'foo%')")
    end

    it "returns nil for an AND expression where none is supported by SQL" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-platform", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-platform", "value" => "bar"}}
      sql, * = MiqExpression.new("AND" => [exp1, exp2]).to_sql
      expect(sql).to be_nil
    end

    it "generates the SQL for an OR expression" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-name", "value" => "bar"}}
      sql, * = MiqExpression.new("OR" => [exp1, exp2]).to_sql
      expect(sql).to eq("(\"vms\".\"name\" LIKE 'foo%' OR \"vms\".\"name\" LIKE '%bar')")
    end

    it "returns nil for an OR expression where one is not supported by SQL" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-platform", "value" => "bar"}}
      sql, * = MiqExpression.new("OR" => [exp1, exp2]).to_sql
      expect(sql).to be_nil
    end

    it "returns nil for an OR expression where none is supported by SQL" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-platform", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-platform", "value" => "bar"}}
      sql, * = MiqExpression.new("OR" => [exp1, exp2]).to_sql
      expect(sql).to be_nil
    end

    it "generates the SQL for a NOT expression" do
      sql, * = MiqExpression.new("NOT" => {"=" => {"field" => "Vm-name", "value" => "foo"}}).to_sql
      expect(sql).to eq("NOT \"vms\".\"name\" = 'foo'")
    end

    it "generates the SQL for a ! expression" do
      sql, * = MiqExpression.new("!" => {"=" => {"field" => "Vm-name", "value" => "foo"}}).to_sql
      expect(sql).to eq("NOT \"vms\".\"name\" = 'foo'")
    end

    it "generates the SQL for an IS NULL expression" do
      sql, * = MiqExpression.new("IS NULL" => {"field" => "Vm-name"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" IS NULL")
    end

    it "generates the SQL for an IS NOT NULL expression" do
      sql, * = MiqExpression.new("IS NOT NULL" => {"field" => "Vm-name"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" IS NOT NULL")
    end

    it "generates the SQL for an IS EMPTY expression" do
      sql, * = MiqExpression.new("IS EMPTY" => {"field" => "Vm-name"}).to_sql
      expect(sql).to eq("(\"vms\".\"name\" IS NULL OR \"vms\".\"name\" = '')")
    end

    it "generates the SQL for an IS NOT EMPTY expression" do
      sql, * = MiqExpression.new("IS NOT EMPTY" => {"field" => "Vm-name"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" IS NOT NULL AND \"vms\".\"name\" != ''")
    end

    it "generates the SQL for a CONTAINS expression with field" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.guest_applications-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"id\" IN (SELECT DISTINCT \"guest_applications\".\"vm_or_template_id\" FROM \"guest_applications\" WHERE \"guest_applications\".\"name\" = 'foo')")
    end

    it "generates the SQL for a CONTAINS expression with field containing a scope" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.users-name", "value" => "foo"}).to_sql
      expected = "\"vms\".\"id\" IN (SELECT DISTINCT \"accounts\".\"vm_or_template_id\" FROM \"accounts\" "\
                 "WHERE \"accounts\".\"name\" = 'foo' AND \"accounts\".\"accttype\" = 'user')"
      expect(sql).to eq(expected)
    end

    it "generates the SQL for a CONTAINS expression with tag" do
      tag = FactoryGirl.create(:tag, :name => "/managed/operations/analysis_failed")
      vm = FactoryGirl.create(:vm_vmware, :tags => [tag])
      exp = {"CONTAINS" => {"tag" => "VmInfra.managed-operations", "value" => "analysis_failed"}}
      sql, * = MiqExpression.new(exp).to_sql
      expect(sql).to eq("vms.id IN (#{vm.id})")
    end

    it "raises an error for an expression with unknown operator" do
      expect do
        MiqExpression.new("FOOBAR" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      end.to raise_error(/operator 'FOOBAR' is not supported/)
    end

    it "should test virtual column FB15509" do
      exp = YAML.load '--- !ruby/object:MiqExpression
      context_type:
      exp:
        CONTAINS:
          field: MiqGroup.vms-disconnected
          value: "false"
      '

      *, attrs = exp.to_sql
      expect(attrs[:supported_by_sql]).to eq(false)
    end

    context "date/time support" do
      it "generates the SQL for an EQUAL expression" do
        sql, * = MiqExpression.new("EQUAL" => {"field" => "Vm-boot_time", "value" => "2016-01-01"}).to_sql
        expect(sql).to eq("vms.boot_time = '2016-01-01T00:00:00Z'")
      end

      it "generates the SQL for a = expression" do
        sql, * = MiqExpression.new("=" => {"field" => "Vm-boot_time", "value" => "2016-01-01"}).to_sql
        expect(sql).to eq("vms.boot_time = '2016-01-01T00:00:00Z'")
      end

      it "generates the SQL for an AFTER expression" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on > '2011-01-10'")
      end

      it "generates the SQL for a > expression" do
        exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on > '2011-01-10'")
      end

      it "generates the SQL for a BEFORE expression" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on < '2011-01-10'")
      end

      it "generates the SQL for a < expression" do
        exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on < '2011-01-10'")
      end

      it "generates the SQL for a >= expression" do
        exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on >= '2011-01-10'")
      end

      it "generates the SQL for a <= expression" do
        exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on <= '2011-01-10'")
      end

      it "generates the SQL for an AFTER expression with date/time" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.last_scan_on > '2011-01-10T09:00:00Z'")
      end

      it "generates the SQL for a > expression with date/time" do
        exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.last_scan_on > '2011-01-10T09:00:00Z'")
      end

      it "generates the SQL for an IS expression" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" = '2011-01-10'")
      end

      it "generates the SQL for a FROM expression" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-09' AND '2011-01-10'")
      end

      it "generates the SQL for a FROM expression with MM/DD/YYYY dates" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-09' AND '2011-01-10'")
      end

      it "generates the SQL for a FROM expression with date/time" do
        exp = MiqExpression.new(
          "FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]}
        )
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-10 08:00:00' AND '2011-01-10 17:00:00'")
      end

      it "generates the SQL for a FROM expression with two identical datetimes" do
        exp = MiqExpression.new(
          "FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]}
        )
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-10 00:00:00' AND '2011-01-10 00:00:00'")
      end
    end

    context "relative date/time support" do
      around { |example| Timecop.freeze("2011-01-11 17:30 UTC") { example.run } }

      it "generates the SQL for an AFTER expression with an 'n Days Ago' value for a date field" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on > '2011-01-09'")
      end

      it "generates the SQL for an AFTER expression with an 'n Days Ago' value for a datetime field" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.last_scan_on > '2011-01-09T23:59:59Z'")
      end

      it "generates the SQL for a BEFORE expression with an 'n Days Ago' value for a date field" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.retires_on < '2011-01-09'")
      end

      it "generates the SQL for a BEFORE expression with an 'n Days Ago' value for a datetime field" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("vms.last_scan_on < '2011-01-09T00:00:00Z'")
      end

      it "generates the SQL for a FROM expression with a 'Last Hour'/'This Hour' value for a datetime field" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-11 16:00:00' AND '2011-01-11 17:59:59'")
      end

      it "generates the SQL for a FROM expression with a 'Last Week'/'Last Week' value for a date field" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-03' AND '2011-01-09'")
      end

      it "generates the SQL for a FROM expression with a 'Last Week'/'Last Week' value for a datetime field" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-03 00:00:00' AND '2011-01-09 23:59:59.999999'")
      end

      it "generates the SQL for a FROM expression with an 'n Months Ago'/'Last Month' value for a datetime field" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2010-11-01 00:00:00' AND '2010-12-31 23:59:59.999999'")
      end

      it "generates the SQL for an IS expression with a 'Today' value for a date field" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-11' AND '2011-01-11'")
      end

      it "generates the SQL for an IS expression with an 'n Hours Ago' value for a date field" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-11' AND '2011-01-11'")
      end

      it "generates the SQL for an IS expression with an 'n Hours Ago' value for a datetime field" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-11 14:00:00' AND '2011-01-11 14:59:59'")
      end
    end
  end

  describe "#to_ruby" do
    it "detects value empty array" do
      exp = MiqExpression.new("INCLUDES" => {"field" => "Vm-name", "value" => "[]"})
      expect(exp.to_ruby).to eq("<value ref=vm, type=string>/virtual/name</value> =~ /\\[\\]/")
    end

    it "raises error if expression contains ruby script" do
      exp = MiqExpression.new("RUBY" => {"field" => "Host-name", "value" => "puts 'Hello world!'"})
      expect { exp.to_ruby }.to raise_error(/Ruby scripts in expressions are no longer supported/)
    end

    it "tests numeric set expressions" do
      exp = MiqExpression.new("=" => {"field" => "Host-enabled_inbound_ports", "value" => "22,427,5988,5989"})
      expect(exp.to_ruby).to eq('<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> == [22,427,5988,5989]')
    end

    # Note: To debug these tests, the following may be helpful:
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"

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
      expect(filter.to_ruby).to eq("<value ref=host, type=string_set>/virtual/service_names</value> == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ALL:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
      '
      expect(filter.to_ruby).to eq("(<value ref=host, type=string_set>/virtual/service_names</value> & ['ntpd','sshd','vmware-vpxa','vmware-webAccess']) == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ANY:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
      '
      expect(filter.to_ruby).to eq("(['ntpd','sshd','vmware-vpxa','vmware-webAccess'] - <value ref=host, type=string_set>/virtual/service_names</value>) != ['ntpd','sshd','vmware-vpxa','vmware-webAccess']")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ONLY:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa"
      '
      expect(filter.to_ruby).to eq("(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []")

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        LIMITED TO:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa"
      '
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
      expect(filter.to_ruby).to eq('<find><search><value ref=host, type=text>/virtual/filesystems/name</value> == "/etc/passwd"</search><check mode=all><value ref=host, type=string>/virtual/filesystems/permissions</value> == "0644"</check></find>')
    end

    it "should test regexp" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        REGULAR EXPRESSION MATCHES:
          field: Host-name
          value: /^[^.]*\.galaxy\..*$/
      '
      expect(filter.to_ruby).to eq('<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/')

      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        REGULAR EXPRESSION MATCHES:
          field: Host-name
          value: ^[^.]*\.galaxy\..*$
      '
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

      expect(filter.to_ruby).to eq('<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == "true"</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> !~ /^.*SLP.*$/</check></find>')
    end

    it "should test fb7726" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        CONTAINS:
          field: Host.filesystems-name
          value: /etc/shadow
      '
      expect(filter.to_ruby).to eq("<exist ref=host>/virtual/filesystems/name/%2fetc%2fshadow</exist>")
    end

    it "should test numbers with methods" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      context_type:
      exp:
        ">=":
          field: Vm-memory_shares
          value: 25.kilobytes
      '
      expect(filter.to_ruby).to eq('<value ref=vm, type=integer>/virtual/memory_shares</value> >= 25600')

      filter = YAML.load '--- !ruby/object:MiqExpression
      context_type:
      exp:
        ">=":
          field: Vm-used_disk_storage
          value: 1,000.megabytes
      '
      expect(filter.to_ruby).to eq('<value ref=vm, type=integer>/virtual/used_disk_storage</value> >= 1048576000')
    end

    context "integration" do
      it "should escape strings" do
        filter = YAML.load '--- !ruby/object:MiqExpression
        exp:
          INCLUDES:
            field: Vm.registry_items-data
            value: $foo
        '
        expect(filter.to_ruby).to eq("<value ref=vm, type=text>/virtual/registry_items/data</value> =~ /\\$foo/")

        data = {"registry_items.data" => "C:\\Documents and Users\\O'Neill, April\\", "/virtual/registry_items/data" => "C:\\Documents and Users\\O'Neill, April\\"}
        expect(Condition.subst(filter.to_ruby, data)).to eq("\"C:\\\\Documents and Users\\\\O'Neill, April\\\\\" =~ /\\$foo/")
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
        expect(filter.to_ruby).to eq("<value type=string>guest_applications.name</value> == \"VMware Tools\"")
        expect(Condition.subst(filter.to_ruby, data)).to eq("\"VMware Tools\" == \"VMware Tools\"")

        filter = YAML.load '--- !ruby/object:MiqExpression
        exp:
          REGULAR EXPRESSION MATCHES:
            field: Vm.guest_applications-vendor
            value: /^[^.]*ware.*$/
        context_type: hash
        '
        expect(filter.to_ruby).to eq("<value type=string>guest_applications.vendor</value> =~ /^[^.]*ware.*$/")
        expect(Condition.subst(filter.to_ruby, data)).to eq('"VMware, Inc." =~ /^[^.]*ware.*$/')
      end
    end

    it "generates the ruby for a STARTS WITH expression" do
      actual = described_class.new("STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /^foo/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an ENDS WITH expression" do
      actual = described_class.new("ENDS WITH" => {"field" => "Vm-name", "value" => "foo"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /foo$/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an AND expression" do
      actual = described_class.new("AND" => [{"=" => {"field" => "Vm-name", "value" => "foo"}},
                                             {"=" => {"field" => "Vm-vendor", "value" => "bar"}}]).to_ruby
      expected = "(<value ref=vm, type=string>/virtual/name</value> == \"foo\" and <value ref=vm, type=string>/virtual/vendor</value> == \"bar\")"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an OR expression" do
      actual = described_class.new("OR" => [{"=" => {"field" => "Vm-name", "value" => "foo"}},
                                            {"=" => {"field" => "Vm-vendor", "value" => "bar"}}]).to_ruby
      expected = "(<value ref=vm, type=string>/virtual/name</value> == \"foo\" or <value ref=vm, type=string>/virtual/vendor</value> == \"bar\")"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a NOT expression" do
      actual = described_class.new("NOT" => {"=" => {"field" => "Vm-name", "value" => "foo"}}).to_ruby
      expected = "!(<value ref=vm, type=string>/virtual/name</value> == \"foo\")"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a ! expression" do
      actual = described_class.new("!" => {"=" => {"field" => "Vm-name", "value" => "foo"}}).to_ruby
      expected = "!(<value ref=vm, type=string>/virtual/name</value> == \"foo\")"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an IS NULL expression" do
      actual = described_class.new("IS NULL" => {"field" => "Vm-name"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> == \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an IS NOT NULL expression" do
      actual = described_class.new("IS NOT NULL" => {"field" => "Vm-name"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> != \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an IS EMPTY expression" do
      actual = described_class.new("IS EMPTY" => {"field" => "Vm-name"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> == \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for an IS NOT EMPTY expression" do
      actual = described_class.new("IS NOT EMPTY" => {"field" => "Vm-name"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> != \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkall" do
      actual = described_class.new(
        "FIND" => {"search"   => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkall" => {">" => {"field" => "Vm.hardware.cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=all><value ref=vm, type=string>/virtual/hardware/cpu_sockets</value> > \"2\"</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkany" do
      actual = described_class.new(
        "FIND" => {"search"   => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkany" => {">" => {"field" => "Vm.hardware.cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=any><value ref=vm, type=string>/virtual/hardware/cpu_sockets</value> > \"2\"</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {">" => {"field" => "Vm.hardware.cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> > 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a KEY EXISTS expression" do
      actual = described_class.new("KEY EXISTS" => {"field" => "Host-settings", "value" => "foo"}).to_ruby
      expected = ["<value ref=host, type=string>/virtual/settings</value>", "\"foo\""]
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a VALUE EXISTS expression" do
      actual = described_class.new("VALUE EXISTS" => {"field" => "Host-settings", "value" => "foo"}).to_ruby
      expected = ["<value ref=host, type=string>/virtual/settings</value>", "\"foo\""]
      expect(actual).to eq(expected)
    end

    it "raises an error for an expression with an invalid operator" do
      expression = described_class.new("FOOBAR" => {"field" => "Vm-name", "value" => "baz"})
      expect { expression.to_ruby }.to raise_error(/operator 'FOOBAR' is not supported/)
    end

    context "date/time support" do
      context "static dates and times with no timezone" do
        it "generates the ruby for an AFTER expression with date value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")
        end

        it "generates the ruby for a > expression date value" do
          exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")
        end

        it "generates the ruby for a BEFORE expression with date value" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")
        end

        it "generates the ruby for a < expression with date value" do
          exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")
        end

        it "generates the ruby for a >= expression with date value" do
          exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-10'.to_date")
        end

        it "generates the ruby for a <= expression with date value" do
          exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date <= '2011-01-10'.to_date")
        end

        it "generates the ruby for a AFTER expression with datetime value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T09:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a > expression with datetime value" do
          exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T09:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a IS expression with date value" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date == '2011-01-10'.to_date")
        end

        it "generates the ruby for a IS expression with datetime value" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T23:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with date values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-09'.to_date && val.to_date <= '2011-01-10'.to_date")
        end

        it "generates the ruby for a FROM expression with date values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-09'.to_date && val.to_date <= '2011-01-10'.to_date")
        end

        it "generates the ruby for a FROM expression with datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T08:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T17:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with identical datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T00:00:00Z'.to_time(:utc)")
        end
      end

      context "static dates and times with a time zone" do
        let(:tz) { "Eastern Time (US & Canada)" }

        it "generates the ruby for a AFTER expression with date value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")
        end

        it "generates the ruby for a > expression with date value" do
          exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-10'.to_date")
        end

        it "generates the ruby for a BEFORE expression with date value" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")
        end

        it "generates the ruby for a < expression with date value" do
          exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-10'.to_date")
        end

        it "generates the ruby for a >= expression with date value" do
          exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-10'.to_date")
        end

        it "generates the ruby for a <= expression with date value" do
          exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date <= '2011-01-10'.to_date")
        end

        it "generates the ruby for a AFTER expression with datetime value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T14:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a > expression with datetime value" do
          exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-10T14:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a IS expression wtih date value" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date == '2011-01-10'.to_date")
        end

        it "generates the ruby for a FROM expression with date values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-09'.to_date && val.to_date <= '2011-01-10'.to_date")
        end

        it "generates the ruby for a FROM expression with datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T13:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T22:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with identical datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-10T05:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T05:00:00Z'.to_time(:utc)")
        end
      end
    end

    context "relative date/time support" do
      around { |example| Timecop.freeze("2011-01-11 17:30 UTC") { example.run } }

      context "relative dates with no time zone" do
        it "generates the ruby for an AFTER expression with date value of n Days Ago" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date > '2011-01-09'.to_date")
        end

        it "generates the ruby for an AFTER expression with datetime value of n Days ago" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time > '2011-01-09T23:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for a BEFORE expression with date value of n Days Ago" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date < '2011-01-09'.to_date")
        end

        it "generates the ruby for a BEFORE expression with datetime value of n Days Ago" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time < '2011-01-09T00:00:00Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with datetime values of Last/This Hour" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T16:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T17:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with date values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")
        end

        it "generates the ruby for a FROM expression with datetime values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-09T23:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with datetime values of n Months Ago/Last Month" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2010-11-01T00:00:00Z'.to_time(:utc) && val.to_time <= '2010-12-31T23:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for an IS expression with datetime value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T00:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-09T23:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for an IS expression with date value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Last Week"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")
        end

        it "generates the ruby for a IS expression with date value of Today" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")
        end

        it "generates the ruby for an IS expression with date value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")
        end

        it "generates the ruby for a IS expression with datetime value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T14:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T14:59:59Z'.to_time(:utc)")
        end
      end

      context "relative time with a time zone" do
        let(:tz) { "Hawaii" }

        it "generates the ruby for a FROM expression with datetime value of Last/This Hour" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T16:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T17:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with date values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")
        end

        it "generates the ruby for a FROM expression with datetime values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T09:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for a FROM expression with datetime values of n Months Ago/Last Month" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2010-11-01T10:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-01T09:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for an IS expression with datetime value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-03T10:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-10T09:59:59Z'.to_time(:utc)")
        end

        it "generates the ruby for an IS expression with date value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Last Week"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-03'.to_date && val.to_date <= '2011-01-09'.to_date")
        end

        it "generates the ruby for an IS expression with date value of Today" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")
        end

        it "generates the ruby for an IS expression with date value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=date>/virtual/retires_on</value>; !val.nil? && val.to_date >= '2011-01-11'.to_date && val.to_date <= '2011-01-11'.to_date")
        end

        it "generates the ruby for an IS expression with datetime value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby(tz)).to eq("val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>; !val.nil? && val.to_time >= '2011-01-11T14:00:00Z'.to_time(:utc) && val.to_time <= '2011-01-11T14:59:59Z'.to_time(:utc)")
        end
      end
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

  describe ".is_numeric?" do
    it "should return true if digits separated by comma and false if another separator used" do
      expect(MiqExpression.is_numeric?('10000.55')).to be_truthy
      expect(MiqExpression.is_numeric?('10,000.55')).to be_truthy
      expect(MiqExpression.is_numeric?('10 000.55')).to be_falsey
    end

    it "should return true if there is method attached to number" do
      expect(MiqExpression.is_numeric?('2,555.hello')).to eq(false)
      expect(MiqExpression.is_numeric?('2,555.kilobytes')).to eq(true)
      expect(MiqExpression.is_numeric?('2,555.55.megabytes')).to eq(true)
    end
  end

  describe ".is_integer?" do
    it "should return true if digits separated by comma and false if another separator used" do
      expect(MiqExpression.is_integer?('2,555')).to eq(true)
      expect(MiqExpression.is_integer?('2 555')).to eq(false)
    end

    it "should return true if there is method attached to number" do
      expect(MiqExpression.is_integer?('2,555.kilobytes')).to eq(true)
      expect(MiqExpression.is_integer?('2,555.hello')).to eq(false)
    end
  end

  describe ".is_plural?" do
    it "should return true if assotiation of field is 'has_many' or 'has_and_belongs_to_many'" do
      field = 'ManageIQ::Providers::InfraManager::Vm.storage-region_description' # vm belong_to storage
      expect(MiqExpression.is_plural?(field)).to be_falsey
    end
  end

  describe ".atom_error" do
    it "should return false if value can be evaluated as regular expression" do
      value = '123[)'
      expect(MiqExpression.atom_error("Host-xx", "regular expression matches", value)).to be_truthy
      value = '/foo/'
      expect(MiqExpression.atom_error("Host-xx", "regular expression matches", value)).to be_falsey
    end

    it "should return true if operator is 'ruby'" do
      # Ruby scripts in expressions are no longer supported.
      expect(MiqExpression.atom_error("VmPerformance-cpu_usage_rate_average", "ruby", '')).to be_truthy
    end

    it "should return false if data type of field is 'string' or 'text'" do
      field = "Vm-vendor"
      expect(MiqExpression.atom_error(field, "START WITH", 'red')).to be_falsey
    end

    it "should return false if field is 'count'" do
      filed = :count
      expect(MiqExpression.atom_error(filed, ">=", '1')).to be_falsey
    end

    it "should return false if data type of field is boolean and value is 'true' or 'false'" do
      field = "Vm-retired"
      expect(MiqExpression.atom_error(field, "=", 'false')).to be_falsey
      expect(MiqExpression.atom_error(field, "=", 'true')).to be_falsey
      expect(MiqExpression.atom_error(field, "=", 'not')).to be_truthy
    end

    it "should return false if data type of field is float and value evaluated to float" do
      field = "VmPerformance-cpu_usage_rate_average"
      expect(MiqExpression.atom_error(field, "=", '')).to be_truthy
      expect(MiqExpression.atom_error(field, "=", '123abc')).to be_truthy
      expect(MiqExpression.atom_error(field, "=", '123')).to be_falsey
      expect(MiqExpression.atom_error(field, "=", '123.456')).to be_falsey
      expect(MiqExpression.atom_error(field, "=", '2,123.456')).to be_falsey
      expect(MiqExpression.atom_error(field, "=", '123.kilobytes')).to be_falsey
    end

    it "should return false if data type of field is integer and value evaluated to integer" do
      field = "Vm-cpu_limit"
      expect(MiqExpression.atom_error(field, "=", '')).to be_truthy
      expect(MiqExpression.atom_error(field, "=", '123.5')).to be_truthy
      expect(MiqExpression.atom_error(field, "=", '123.abc')).to be_truthy
      expect(MiqExpression.atom_error(field, "=", '123')).to be_falsey
      expect(MiqExpression.atom_error(field, "=", '2,123')).to be_falsey
    end

    it "should return false if data type of field is datetime and value evaluated to datetime" do
      field = "Vm-created_on"
      expect(MiqExpression.atom_error(field, "=", Time.current.to_s)).to be_falsey
      expect(MiqExpression.atom_error(field, "=", "123456")).to be_truthy
    end

    it "should return false if most resent date is second element in array" do
      field = "Vm-state_changed_on"
      expect(MiqExpression.atom_error(field, "FROM", ["7 Days Ago", "Today"])).to be_falsey
      expect(MiqExpression.atom_error(field, "FROM", ["Today", "7 Days Ago"])).to be_truthy
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
    end
  end

  describe "#to_human" do
    it "generates a human readable string for a 'FIELD' expression" do
      exp = MiqExpression.new(">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes"})
      expect(exp.to_human).to eq('VM and Instance : Allocated Disk Storage > 5 MB')
    end

    it "generates a human readable string for a FIELD expression with alias" do
      exp = MiqExpression.new(">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes",
                                    "alias" => "Disk"})
      expect(exp.to_human).to eq('Disk > 5 MB')
    end

    it "generates a human readable string for a FIND/CHECK expression" do
      exp = MiqExpression.new("FIND" => {"search"   => {"STARTS WITH" => {"field" => "Vm.advanced_settings-name",
                                                                          "value" => "X"}},
                                         "checkall" => {"=" => {"field" => "Vm.advanced_settings-read_only",
                                                                "value" => "true"}}})
      expect(exp.to_human).to eq('FIND VM and Instance.Advanced Settings : '\
        'Name STARTS WITH "X" CHECK ALL Read Only = "true"')
    end

    it "generates a human readable string for a FIND/CHECK expression with alias" do
      exp = MiqExpression.new("FIND" => {"search"   => {"STARTS WITH" => {"field" => "Vm.advanced_settings-name",
                                                                          "value" => "X",
                                                                          "alias" => "Settings Name"}},
                                         "checkall" => {"=" => {"field" => "Vm.advanced_settings-read_only",
                                                                "value" => "true"}}})
      expect(exp.to_human).to eq('FIND Settings Name STARTS WITH "X" CHECK ALL Read Only = "true"')
    end

    it "generates a human readable string for a COUNT expression" do
      exp = MiqExpression.new({">" => {"count" => "Vm.snapshots", "value" => "1"}})
      expect(exp.to_human).to eq("COUNT OF VM and Instance.Snapshots > 1")
    end

    it "generates a human readable string for a COUNT expression with alias" do
      exp = MiqExpression.new(">" => {"count" => "Vm.snapshots", "value" => "1", "alias" => "Snaps"})
      expect(exp.to_human).to eq("COUNT OF Snaps > 1")
    end

    context "TAG type expression" do
      before do
        # tags contain the root tenant's name
        Tenant.seed

        category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
        FactoryGirl.create(:classification, :parent_id => category.id, :name => 'prod', :description => 'Production')
      end

      it "generates a human readable string for a TAG expression" do
        exp = MiqExpression.new("CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod"})
        expect(exp.to_human).to eq("Host / Node.My Company Tags : Environment CONTAINS 'Production'")
      end

      it "generates a human readable string for a TAG expression with alias" do
        exp = MiqExpression.new("CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod",
                                               "alias" => "Env"})
        expect(exp.to_human).to eq("Env CONTAINS 'Production'")
      end
    end

    context "when given values with relative dates" do
      it "generates a human readable string for a AFTER '2 Days Ago' expression" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        expect(exp.to_human).to eq('VM and Instance : Retires On AFTER "2 Days Ago"')
      end

      it "generates a human readable string for a BEFORE '2 Days ago' expression" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        expect(exp.to_human).to eq('VM and Instance : Retires On BEFORE "2 Days Ago"')
      end

      it "generates a human readable string for a FROM 'Last Hour' THROUGH 'This Hour' expression" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "Last Hour" THROUGH "This Hour"')
      end

      it "generates a human readable string for a FROM 'Last Week' THROUGH 'Last Week' expression" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        expect(exp.to_human).to eq('VM and Instance : Retires On FROM "Last Week" THROUGH "Last Week"')
      end

      it "generates a human readable string for a FROM '2 Months ago' THROUGH 'Last Month' expression" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time FROM "2 Months Ago" THROUGH "Last Month"')
      end

      it "generates a human readable string for a IS '3 Hours Ago' expression" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time IS "3 Hours Ago"')
      end
    end

    context "when giving value with static dates and times" do
      it "generates a human readable string for a AFTER expression with date without time" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On AFTER "2011-01-10"')
      end

      it "generates a human readable string for a AFTER expression with date and time" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time AFTER "2011-01-10 9:00"')
      end

      it "generates a human readable string for a BEFORE expression with date without time" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On BEFORE "2011-01-10"')
      end

      it "generates a human readable string for a '>' expression with date without time" do
        exp = MiqExpression.new(">" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On > "2011-01-10"')
      end

      it "generates a human readable string for a '>' expression with date and time" do
        exp = MiqExpression.new(">" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time > "2011-01-10 9:00"')
      end

      it "generates a human readable string for a '<' expression with date without time" do
        exp = MiqExpression.new("<" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On < "2011-01-10"')
      end

      it "generates a human readable string for a '>=' expression with date and time" do
        exp = MiqExpression.new(">=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On >= "2011-01-10"')
      end

      it "generates a human readable string for a '<=' expression with date without time" do
        exp = MiqExpression.new("<=" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On <= "2011-01-10"')
      end

      it "generates a human readable string for a 'IS' with date without time" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        expect(exp.to_human).to eq('VM and Instance : Retires On IS "2011-01-10"')
      end

      it "generates a human readable string for a FROM THROUGH expression with date format: 'yyyy-mm-dd'" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        expect(exp.to_human).to eq('VM and Instance : Retires On FROM "2011-01-09" THROUGH "2011-01-10"')
      end

      it "generates a human readable string for a FROM THROUGH expression with date format: 'mm/dd/yyyy'" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
        expect(exp.to_human).to eq('VM and Instance : Retires On FROM "01/09/2011" THROUGH "01/10/2011"')
      end

      it "generates a human readable string for a FROM THROUGH expression with date and time" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on",
                                           "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
        expect(exp.to_human).to eq('VM and Instance : Last Analysis Time ' \
          'FROM "2011-01-10 8:00" THROUGH "2011-01-10 17:00"')
      end
    end
  end

  context "quick search" do
    let(:exp) { {"=" => {"field" => "Vm-name", "value" => "test"}} }
    let(:qs_exp) { {"=" => {"field" => "Vm-name", "value" => :user_input}} }
    let(:complex_qs_exp) do
      {
        "AND" => [
          {"=" => {"field" => "Vm-name", "value" => "test"}},
          {"=" => {"field" => "Vm-name", "value" => :user_input}}
        ]
      }
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

  describe ".get_col_type" do
    subject { described_class.get_col_type(@field) }

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      expect(subject).to eq(described_class.get_col_type("Vm-name"))
    end

    it "with managed-field" do
      @field = "managed.location"
      expect(subject).to eq(:string)
    end

    it "with model.managed-in_field" do
      @field = "Vm.managed-service_level"
      expect(subject).to eq(:string)
    end

    it "with model.last.managed-in_field" do
      @field = "Vm.host.managed-environment"
      expect(subject).to eq(:string)
    end

    it "with valid model-in_field" do
      @field = "Vm-cpu_limit"
      allow(described_class).to receive_messages(:col_type => :some_type)
      expect(subject).to eq(:some_type)
    end

    it "with invalid model-in_field" do
      @field = "abc-name"
      expect(subject).to be_nil
    end

    it "with valid model.association-in_field" do
      @field = "Vm.guest_applications-vendor"
      allow(described_class).to receive_messages(:col_type => :some_type)
      expect(subject).to eq(:some_type)
    end

    it "with invalid model.association-in_field" do
      @field = "abc.host-name"
      expect(subject).to be_nil
    end

    it "with model-invalid_field" do
      @field = "Vm-abc"
      expect(subject).to be_nil
    end

    it "with field without model" do
      @field = "storage"
      expect(subject).to be_nil
    end
  end

  describe ".parse_field" do
    subject { described_class.parse_field(@field) }

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      expect(subject).to eq(["Vm", [], "name"])
    end

    it "with managed-field" do
      @field = "managed.location"
      expect(subject).to eq(["managed", ["location"], "managed.location"])
    end

    it "with model.managed-in_field" do
      @field = "Vm.managed-service_level"
      expect(subject).to eq(["Vm", ["managed"], "service_level"])
    end

    it "with model.last.managed-in_field" do
      @field = "Vm.host.managed-environment"
      expect(subject).to eq(["Vm", ["host", "managed"], "environment"])
    end

    it "with valid model-in_field" do
      @field = "Vm-cpu_limit"
      expect(subject).to eq(["Vm", [], "cpu_limit"])
    end

    it "with field without model" do
      @field = "storage"
      expect(subject).to eq(["storage", [], "storage"])
    end
  end

  describe ".model_details" do
    before do
      # tags contain the root tenant's name
      Tenant.seed

      cat = FactoryGirl.create(:classification,
                               :description  => "Auto Approve - Max CPU",
                               :name         => "prov_max_cpu",
                               :single_value => true,
                               :show         => true,
                               :parent_id    => 0
                              )
      cat.add_entry(:description  => "1",
                    :read_only    => "0",
                    :syntax       => "string",
                    :name         => "1",
                    :example_text => nil,
                    :default      => true,
                    :single_value => "1"
                   )
    end

    context "with :typ=>tag" do
      it "VmInfra" do
        result = described_class.model_details("ManageIQ::Providers::InfraManager::Vm", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("Virtual Machine.My Company Tags : Auto Approve - Max CPU")
      end

      it "VmCloud" do
        result = described_class.model_details("ManageIQ::Providers::CloudManager::Vm", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("Instance.My Company Tags : Auto Approve - Max CPU")
        expect(result.map(&:first)).not_to include("Instance.VM and Instance.My Company Tags : Auto Approve - Max CPU")
      end

      it "VmOrTemplate" do
        result = described_class.model_details("VmOrTemplate",
                                               :typ             => "tag",
                                               :include_model   => true,
                                               :include_my_tags => true,
                                               :userid          => "admin"
                                              )
        expect(result.map(&:first)).to include("VM or Template.My Company Tags : Auto Approve - Max CPU")
      end

      it "TemplateInfra" do
        result = described_class.model_details("ManageIQ::Providers::InfraManager::Template", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("Template.My Company Tags : Auto Approve - Max CPU")
      end

      it "TemplateCloud" do
        result = described_class.model_details("ManageIQ::Providers::CloudManager::Template", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("Image.My Company Tags : Auto Approve - Max CPU")
      end

      it "MiqTemplate" do
        result = described_class.model_details("MiqTemplate", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("VM Template and Image.My Company Tags : Auto Approve - Max CPU")
      end

      it "EmsInfra" do
        result = described_class.model_details("ManageIQ::Providers::InfraManager", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("Infrastructure Provider.My Company Tags : Auto Approve - Max CPU")
      end

      it "EmsCloud" do
        result = described_class.model_details("ManageIQ::Providers::CloudManager", :typ => "tag", :include_model => true, :include_my_tags => true, :userid => "admin")
        expect(result.map(&:first)).to include("Cloud Provider.My Company Tags : Auto Approve - Max CPU")
      end
    end

    context "with :typ=>all" do
      it "VmOrTemplate" do
        result = described_class.model_details("VmOrTemplate",
                                               :typ           => "all",
                                               :include_model => false,
                                               :include_tags  => true)
        expect(result.map(&:first)).to include("My Company Tags : Auto Approve - Max CPU")
      end

      it "Service" do
        result = described_class.model_details("Service", :typ => "all", :include_model => false, :include_tags => true)
        expect(result.map(&:first)).to include("My Company Tags : Auto Approve - Max CPU")
      end

      it "Supports classes derived form ActsAsArModel" do
        result = described_class.model_details("ChargebackVm", :typ => "all", :include_model => false, :include_tags => true)
        expect(result.map(&:first)[0]).to eq(" CPU Total Cost")
      end
    end
  end

  context ".build_relats" do
    it "AvailabilityZone" do
      result = described_class.build_relats("AvailabilityZone")
      expect(result.fetch_path(:reflections, :ext_management_system, :parent, :class_path).split(".").last).to eq("manageiq_providers_cloud_manager")
      expect(result.fetch_path(:reflections, :ext_management_system, :parent, :assoc_path).split(".").last).to eq("ext_management_system")
    end

    it "VmInfra" do
      result = described_class.build_relats("ManageIQ::Providers::InfraManager::Vm")
      expect(result.fetch_path(:reflections, :evm_owner, :parent, :class_path).split(".").last).to eq("evm_owner")
      expect(result.fetch_path(:reflections, :evm_owner, :parent, :assoc_path).split(".").last).to eq("evm_owner")
      expect(result.fetch_path(:reflections, :linux_initprocesses, :parent, :class_path).split(".").last).to eq("linux_initprocesses")
      expect(result.fetch_path(:reflections, :linux_initprocesses, :parent, :assoc_path).split(".").last).to eq("linux_initprocesses")
    end

    it "Vm" do
      result = described_class.build_relats("Vm")
      expect(result.fetch_path(:reflections, :users, :parent, :class_path).split(".").last).to eq("users")
      expect(result.fetch_path(:reflections, :users, :parent, :assoc_path).split(".").last).to eq("users")
    end

    it "OrchestrationStack" do
      result = described_class.build_relats("ManageIQ::Providers::CloudManager::OrchestrationStack")
      expect(result.fetch_path(:reflections, :vms, :parent, :class_path).split(".").last).to eq("manageiq_providers_cloud_manager_vms")
      expect(result.fetch_path(:reflections, :vms, :parent, :assoc_path).split(".").last).to eq("vms")
    end
  end

  context ".determine_relat_path" do
    subject { described_class.determine_relat_path(@ref) }

    it "when association name is same as class name" do
      @ref = Vm.reflect_on_association(:miq_group)
      expect(subject).to eq(@ref.name.to_s)
    end

    it "when association name is different from class name" do
      @ref = Vm.reflect_on_association(:evm_owner)
      expect(subject).to eq(@ref.name.to_s)
    end

    context "when class name is a subclass of association name" do
      it "one_to_one relation" do
        @ref = AvailabilityZone.reflect_on_association(:ext_management_system)
        expect(subject).to eq(@ref.klass.model_name.singular)
      end

      it "one_to_many relation" do
        @ref = ManageIQ::Providers::CloudManager::OrchestrationStack.reflections_with_virtual[:vms]
        expect(subject).to eq(@ref.klass.model_name.plural)
      end
    end
  end

  describe ".get_col_operators" do
    subject { described_class.get_col_operators(@field) }

    it "returns array of available operations if parameter is :count" do
      @field = :count
      expect(subject).to contain_exactly("=", "!=", "<", "<=", ">=", ">")
    end

    it "returns list of available operations if parameter is :regkey" do
      @field = :regkey
      expect(subject).to contain_exactly("=",
                                         "STARTS WITH",
                                         "ENDS WITH",
                                         "INCLUDES",
                                         "IS NULL",
                                         "IS NOT NULL",
                                         "IS EMPTY",
                                         "IS NOT EMPTY",
                                         "REGULAR EXPRESSION MATCHES",
                                         "REGULAR EXPRESSION DOES NOT MATCH",
                                         "KEY EXISTS",
                                         "VALUE EXISTS")
    end

    it "returns list of available operations for field type 'string'" do
      @field = "ManageIQ::Providers::InfraManager::Vm.advanced_settings-name"
      expect(subject).to contain_exactly("=",
                                         "STARTS WITH",
                                         "ENDS WITH",
                                         "INCLUDES",
                                         "IS NULL",
                                         "IS NOT NULL",
                                         "IS EMPTY",
                                         "IS NOT EMPTY",
                                         "REGULAR EXPRESSION MATCHES",
                                         "REGULAR EXPRESSION DOES NOT MATCH")
    end

    it "returns list of available operations for field type 'integer'" do
      @field = "ManageIQ::Providers::InfraManager::Vm-cpu_limit"
      expect(subject).to contain_exactly("=", "!=", "<", "<=", ">=", ">", "RUBY")
    end

    it "returns list of available operations for field type 'float'" do
      @field = "Storage-v_provisioned_percent_of_total"
      expect(subject).to contain_exactly("=", "!=", "<", "<=", ">=", ">", "RUBY")
    end

=begin
    # there is no example of fields with fixnum datatype available for expression builder
    it "returns list of available operations for field type 'fixnum'" do
      @field = ?
      expect(subject).to eq(["=", "!=", "<", "<=", ">=", ">", "RUBY"])
    end
=end

    it "returns list of available operations for field type 'string_set'" do
      @field = "ManageIQ::Providers::InfraManager::Vm-hostnames"
      expect(subject).to contain_exactly("INCLUDES ALL", "INCLUDES ANY", "LIMITED TO")
    end

    it "returns list of available operations for field type 'numeric_set'" do
      @field = "Host-all_enabled_ports"
      expect(subject).to contain_exactly("INCLUDES ALL", "INCLUDES ANY", "LIMITED TO")
    end

    it "returns list of available operations for field type 'boolean'" do
      @field = "ManageIQ::Providers::InfraManager::Vm-active"
      expect(subject).to contain_exactly("=", "IS NULL", "IS NOT NULL")
    end

    it "returns list of available operations for field type 'date'" do
      @field = "ManageIQ::Providers::InfraManager::Vm-retires_on"
      expect(subject).to contain_exactly("IS", "BEFORE", "AFTER", "FROM", "IS EMPTY", "IS NOT EMPTY")
    end

    it "returns list of available operations for field type 'datetime'" do
      @field = "ManageIQ::Providers::InfraManager::Vm-ems_created_on"
      expect(subject).to contain_exactly("IS", "BEFORE", "AFTER", "FROM", "IS EMPTY", "IS NOT EMPTY")
    end

    it "returns list of available operations for field with not recognized type" do
      @field = "Hello-world"
      expect(subject).to contain_exactly("=",
                                         "STARTS WITH",
                                         "ENDS WITH",
                                         "INCLUDES",
                                         "IS NULL",
                                         "IS NOT NULL",
                                         "IS EMPTY",
                                         "IS NOT EMPTY",
                                         "REGULAR EXPRESSION MATCHES",
                                         "REGULAR EXPRESSION DOES NOT MATCH")
    end
  end

  describe ".get_col_info" do
    it "return column info for model-virtual field" do
      field = "VmInfra-archived"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :boolean,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :boolean,
        :include                        => {},
        :tag                            => false,
        :virtual_column                 => true,
        :virtual_reflection             => false
      )
    end

    it "return column info for managed-field" do
      tag = "managed-location"
      col_info = described_class.get_col_info(tag)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :include                        => {},
        :tag                            => true,
        :virtual_column                 => false,
        :virtual_reflection             => false
      )
    end

    it "return column info for model.managed-field" do
      tag = "VmInfra.managed-operations"
      col_info = described_class.get_col_info(tag)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :include                        => {},
        :tag                            => true,
        :virtual_column                 => false,
        :virtual_reflection             => false
      )
    end

    it "return column info for model.association.managed-field" do
      tag = "Vm.host.managed-environment"
      col_info = described_class.get_col_info(tag)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :include                        => {},
        :tag                            => true,
        :virtual_column                 => false,
        :virtual_reflection             => false
      )
    end

    it "return column info for model-field" do
      field = "ManageIQ::Providers::InfraManager::Vm-cpu_limit"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :integer,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :integer,
        :include                        => {},
        :tag                            => false,
        :virtual_column                 => false,
        :virtual_reflection             => false
      )
    end

    it "return column info for model.association-field" do
      field = "ManageIQ::Providers::InfraManager::Vm.guest_applications-vendor"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :string,
        :include                        => {:guest_applications => {}},
        :tag                            => false,
        :virtual_column                 => false,
        :virtual_reflection             => false
      )
    end

    it "return column info for model.virtualassociation..virtualassociation-field" do
      field = "ManageIQ::Providers::InfraManager::Vm.service.user.vms-active"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :boolean,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :boolean,
        :include                        => {},
        :tag                            => false,
        :virtual_column                 => true,
        :virtual_reflection             => true
      )
    end
  end

  describe "#sql_supports_atom?" do
    context "expression key is 'CONTAINS'" do
      context "operations with 'tag'" do
        it "returns true for tag of the main model" do
          expression = {"CONTAINS" => {"tag" => "VmInfra.managed-operations", "value" => "analysis_failed"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(true)
        end

        it "returns false for tag of associated model" do
          field = "Vm.ext_management_system.managed-openshiftroles"
          expression = {"CONTAINS" => {"tag" => field, "value" => "node"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end
      end

      context "operation with 'field'" do
        it "returns false if format of field is model.association..association-field" do
          field = "ManageIQ::Providers::InfraManager::Vm.service.user.vms-active"
          expression = {"CONTAINS" => {"field" => field, "value" => "true"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end

        it "returns false if field belongs to virtual_has_many association" do
          field = "ManageIQ::Providers::InfraManager::Vm.file_shares-type"
          expression = {"CONTAINS" => {"field" => field, "value" => "abc"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end

        it "returns false if field belongs to 'has_and_belongs_to_many' association" do
          field = "ManageIQ::Providers::InfraManager::Vm.storages-name"
          expression = {"CONTAINS" => {"field" => field, "value" => "abc"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end

        it "returns false if field belongs to 'has_many' polymorhic/polymorhic association" do
          field = "ManageIQ::Providers::InfraManager::Vm.advanced_settings-region_number"
          expression = {"CONTAINS" => {"field" => field, "value" => "1"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end

        it "returns true if field belongs to 'has_many' association" do
          field = "ManageIQ::Providers::InfraManager::Vm.registry_items-name"
          expression = {"CONTAINS" => {"field" => field, "value" => "abc"}}
          expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(true)
        end
      end
    end

    context "expression key is 'INCLUDE'" do
      it "returns false for model-virtualfield" do
        field = "ManageIQ::Providers::InfraManager::Vm-v_datastore_path"
        expression = {"INCLUDES" => {"field" => field, "value" => "abc"}}
        expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(false)
      end

      it "returns true for model-field" do
        field = "ManageIQ::Providers::InfraManager::Vm-location"
        expression = {"INCLUDES" => {"field" => field, "value" => "abc"}}
        expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(true)
      end

      it "returns false for model.association.virtualfield" do
        field = "ManageIQ::Providers::InfraManager::Vm.ext_management_system-hostname"
        expression = {"INCLUDES" => {"field" => field, "value" => "abc"}}
        expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(false)
      end

      it "returns true for model.accociation.field" do
        field = "ManageIQ::Providers::InfraManager::Vm.ext_management_system-name"
        expression = {"INCLUDES" => {"field" => field, "value" => "abc"}}
        expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(true)
      end

      it "returns false if format of field is model.association..association-field" do
        field = "ManageIQ::Providers::InfraManager::Vm.service.miq_request-v_approved_by"
        expression = {"INCLUDES" => {"field" => field, "value" => "abc"}}
        expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(false)
      end
    end

    it "returns false if expression key is 'FIND'" do
      expect(described_class.new(nil).sql_supports_atom?("FIND" => {})).to eq(false)
    end

    it "returns false if expression key is 'REGULAR EXPRESSION MATCHES'" do
      field = "ManageIQ::Providers::InfraManager::Vm-name"
      expression = {"REGULAR EXPRESSION MATCHES" => {"filed" => field, "value" => "\w+"}}
      expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
    end

    it "returns false if expression key is 'REGULAR EXPRESSION DOES NOT MATCH'" do
      field = "ManageIQ::Providers::InfraManager::Vm-name"
      expression = {"REGULAR EXPRESSION DOES NOT MATCH" => {"filed" => field, "value" => "\w+"}}
      expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
    end

    it "returns false if expression key is not 'CONTAINS' and operand is 'TAG'" do
      # UI does not allow to create this kind of expression:
      expression = {"=" => {"tag" => "Vm-vendor"}}
      expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(false)
    end

    it "returns false if operand is'COUNT' on model.association" do
      association = "ManageIQ::Providers::InfraManager::Vm.users"
      expression = {">" => {"count" => association, "value" => "10"}}
      expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(false)
    end

    it "returns false for model.association-virtualfield" do
      field = "ManageIQ::Providers::InfraManager::Vm.storage-v_used_space_percent_of_total"
      expression = {">=" => {"field" => field, "value" => "50"}}
      expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(false)
    end

    it "returns true for model-field" do
      field = "ManageIQ::Providers::InfraManager::Vm-vendor"
      expression = {"=" => {"field" => field, "value" => "redhat"}}
      expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(true)
    end

    it "returns true for model.assoctiation-field" do
      field = "ManageIQ::Providers::InfraManager::Vm.ext_management_system-name"
      expression = {"STARTS WITH" => {"field" => field, "value" => "abc"}}
      expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(true)
    end

    it "returns false if column excluded from processing for adhoc performance metrics" do
      field = "EmsClusterPerformance-cpu_usagemhz_rate_average"
      expression = {">=" => {"field" => field, "value" => "0"}}
      obj = described_class.new(expression)
      obj.preprocess_options = {:vim_performance_daily_adhoc => true}
      expect(obj.sql_supports_atom?(expression)).to eq(false)
    end

    it "returns true if column is not excluded from processing for adhoc performance metrics" do
      field = "EmsClusterPerformance-derived_cpu_available"
      expression = {">=" => {"field" => field, "value" => "0"}}
      obj = described_class.new(expression)
      obj.preprocess_options = {:vim_performance_daily_adhoc => true}
      expect(obj.sql_supports_atom?(expression)).to eq(true)
    end
  end

  describe "#field_in_sql?" do
    it "returns false for model.virtualfield" do
      field = "ManageIQ::Providers::InfraManager::Vm-archived"
      expression = {"=" => {"field" => field, "value" => "true"}}
      expect(described_class.new(expression).field_in_sql?(field)).to eq(false)
    end

    it "returns false for model.association-virtualfield" do
      field = "ManageIQ::Providers::InfraManager::Vm.storage-v_used_space_percent_of_total"
      expression = {">=" => {"field" => field, "value" => "50"}}
      expect(described_class.new(expression).field_in_sql?(field)).to eq(false)
    end

    it "returns true for model-field" do
      field = "ManageIQ::Providers::InfraManager::Vm-vendor"
      expression = {"=" => {"field" => field, "value" => "redhat"}}
      expect(described_class.new(expression).field_in_sql?(field)).to eq(true)
    end

    it "returns true for model.association-field" do
      field = "ManageIQ::Providers::InfraManager::Vm.guest_applications-vendor"
      expression = {"CONTAINS" => {"field" => field, "value" => "redhat"}}
      expect(described_class.new(expression).field_in_sql?(field)).to eq(true)
    end

    it "returns false if column excluded from processing for adhoc performance metrics" do
      field = "EmsClusterPerformance-cpu_usagemhz_rate_average"
      expression = {">=" => {"field" => field, "value" => "0"}}
      obj = described_class.new(expression)
      obj.preprocess_options = {:vim_performance_daily_adhoc => true}
      expect(obj.field_in_sql?(field)).to eq(false)
    end

    it "returns true if column not excluded from processing for adhoc performance metrics" do
      field = "EmsClusterPerformance-derived_cpu_available"
      expression = {">=" => {"field" => field, "value" => "0"}}
      obj = described_class.new(expression)
      obj.preprocess_options = {:vim_performance_daily_adhoc => true}
      expect(obj.field_in_sql?(field)).to eq(true)
    end
  end
end
