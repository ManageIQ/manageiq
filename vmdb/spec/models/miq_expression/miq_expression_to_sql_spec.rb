require "spec_helper"

module MiqExpressionToSqlSpec
  @@skip_test = true
  @@verbose = false
  ActiveRecord::Base.establish_connection(:adapter => "postgresql", :host => "localhost", :username => "root", :password => "smartvm", :database => "sp64_gt_perf_1") unless @@skip_test

  describe "expression to sql" do
    def dump_exp(exp)
      if @@verbose
        puts
        puts "Expression:"
        puts YAML.dump(exp)

        processed, attrs = exp.preprocess_for_sql(exp.exp.deep_clone)
        puts "\nExpression Processed:"
        unless processed.nil?
          puts YAML.dump(processed)
        else
          puts "EXPRESSION IS EMPTY"
          return
        end

        sql = exp._to_sql(processed)
        puts "\nExpression SQL:"
        puts sql

        puts "\nExpression:"
        puts exp.pretty_inspect
      end
    end

    it "should test_basic" do
      pending "should be removed or not skipped"
      unless @@skip_test
        exp = MiqReport.find(58).conditions
        puts "Expression:"
        puts YAML.dump(exp.exp)

        processed, attrs = exp.preprocess_for_sql(exp.exp.deep_clone)
        puts "\nExpression Processed:"
        puts YAML.dump(processed)

        sql = exp._to_sql(processed)
        puts "\nExpression SQL:"
        puts sql
      end
    end

    it "should test_full" do
      pending "should be removed or not skipped"
      unless @@skip_test
        MiqReport.all.each { |r|
          next if r.conditions.blank?
          puts "-----------------------------------------------------------------------------------"
          puts "Report: Id: #{r.id}, Name: #{r.name}\n"
          lambda { dump_exp(r.conditions) }.should_not raise_error
          puts "-----------------------------------------------------------------------------------"
        }
      end
    end

    it "should test_basic_sql" do
      pending "should be removed or not skipped"
      unless @@skip_test
        r = MiqReport.find(98)
        puts "Expression:"
        puts YAML.dump(r.conditions.exp)

        sql, incl = r.conditions.to_sql
        puts "SQL:      #{sql}"
        unless sql.nil?
          MiqExpression.deep_merge_hash(incl, r.get_include_for_find(r.include))
          puts "Includes: #{incl.inspect}"
          count = eval(r.db).count(:conditions => sql, :include => incl)
          puts "Count:    #{count}"
        end
      end
    end

    it "should test_full_sql" do
      pending "should be removed or not skipped"
      unless @@skip_test
        MiqReport.all.each { |r|
          next if r.conditions.blank?
          puts "-----------------------------------------------------------------------------------"
          puts "Report: Id: #{r.id}, Name: #{r.name}\n"
          puts
          puts "Expression: #{r.conditions.to_human}"
          lambda {
            sql, incl = r.conditions.to_sql
            puts "SQL:      #{sql}"
            puts "Includes: #{incl.inspect}"

            next if sql.blank?

            # Test sql
            MiqExpression.deep_merge_hash(incl, r.get_include_for_find(r.include))
            puts "Includes: #{incl.inspect}"
            count = eval(r.db).count(:conditions => sql, :include => incl)
            puts "Count: #{count}"
          }.should_not raise_error
          puts "-----------------------------------------------------------------------------------"
        }
      end
    end

    it "should test_nested_or_expression" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      and:
      - IS NOT NULL:
          field: Vm-name
          value: ""
      - IS NOT EMPTY:
          field: Vm-description
          value: ""
      - or:
        - ">":
            field: Vm-num_cpu
            value: "0"
        - "=":
            field: Vm-os_image_name
            value: linux
      '
      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      sql.should == "((vms.name IS NOT NULL) AND (vms.description IS NOT NULL))"
      lambda { Vm.count(:conditions=>sql, :include=>incl) }.should_not raise_error
      attrs[:supported_by_sql].should_not be_true
    end

    it "should test_deep_nested_or_expression" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      and:
      - IS NOT NULL:
          field: Vm-name
          value: ""
      - IS NOT EMPTY:
          field: Vm-description
          value: ""
      - and:
        - IS NOT NULL:
            field: Vm.host-name
            value: ""
        - or:
          - ">":
              field: Vm-num_cpu
              value: "0"
          - "=":
              field: Vm-os_image_name
              value: linux
      '
      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      sql.should == "((vms.name IS NOT NULL) AND (vms.description IS NOT NULL) AND ((hosts.name IS NOT NULL)))"
      lambda { Vm.count(:conditions=>sql, :include=>incl) }.should_not raise_error
      attrs[:supported_by_sql].should_not be_true
    end

    it "should test_sql_fully_supported_expression" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      and:
      - IS NOT NULL:
          field: Vm-name
          value: ""
      - IS NOT EMPTY:
          field: Vm-description
          value: ""
      - and:
        - IS NOT NULL:
            field: Vm.host-name
            value: ""
      '
      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      sql.should == "((vms.name IS NOT NULL) AND (vms.description IS NOT NULL) AND ((hosts.name IS NOT NULL)))"
      lambda { Vm.count(:conditions=>sql, :include=>incl) }.should_not raise_error
      attrs[:supported_by_sql].should be_true
    end

    it "should test_sql_unsupported_expression_1" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      and:
      - IS NOT NULL:
          field: Vm-name
          value: ""
      - IS NOT EMPTY:
          field: Vm-description
          value: ""
      - and:
        - IS NOT NULL:
            field: Vm.parent_resource_pool-name
            value: ""
      '
      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      sql.should == "((vms.name IS NOT NULL) AND (vms.description IS NOT NULL))"
      lambda { Vm.count(:conditions=>sql, :include=>incl) }.should_not raise_error
      attrs[:supported_by_sql].should_not be_true
    end

    it "should test_sql_unsupported_expression_2" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      and:
      - IS NOT NULL:
          field: Vm-name
          value: ""
      - IS NOT EMPTY:
          field: Vm-description
          value: ""
      - and:
        - IS NOT NULL:
            field: Vm-host_name
            value: ""
      '
      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      sql.should == "((vms.name IS NOT NULL) AND (vms.description IS NOT NULL))"
      lambda { Vm.count(:conditions=>sql, :include=>incl) }.should_not raise_error
      attrs[:supported_by_sql].should_not be_true
    end

    it "should test_sql_like_expression" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      INCLUDES:
        field: Vm-os_image_name
        value: Windows
      '
      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should_not be_true
      sql.should be_nil
      lambda { Vm.count(:conditions=>sql, :include=>incl) }.should_not raise_error
    end

    it "should test_fb10191" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      CONTAINS:
        value: httpd
        field: Vm.linux_initprocesses-name
      '

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should be_true
      sql.should == "vms.id IN (SELECT DISTINCT vm_or_template_id FROM system_services WHERE (name = 'httpd') AND (typename = 'linux_initprocess' OR typename = 'linux_systemd'))"

      exp = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      CONTAINS:
        value: GT
        field: Vm.users-name
      '

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should be_true
      sql.should == "vms.id IN (SELECT DISTINCT vm_or_template_id FROM accounts WHERE (name = 'GT') AND (\"accttype\" = 'user'))"
    end

    it "should test_fb10645" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      and:
      - "=":
          value: "1"
          field: Vm-autostart
      - not:
          and:
          - "=":
              value: "true"
              field: Vm-busy
          - "=":
              value: "2"
              field: Vm-cpu_limit
      '

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should be_true

      sqlserver = ActiveRecord::Base.connection.adapter_name == "SQLServer"
      sql.should == "(vms.autostart = #{'N' if sqlserver}'1' AND NOT (vms.busy = #{'N' if sqlserver}'true' AND vms.cpu_limit = 2))"
    end

    it "should test_preprocess_options_for_vim_performance_daily" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    context_type:
    exp:
      and:
      - "=":
          field: VmPerformance-resource_name
          value: Anti-Spam1_D1
      - ">=":
          field: VmPerformance-cpu_usagemhz_rate_average
          value: "0"
      '
      exp.preprocess_options = {:vim_performance_daily_adhoc => true}

      dump_exp(exp)

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should_not be_true

      sqlserver = ActiveRecord::Base.connection.adapter_name == "SQLServer"
      sql.should == "(metric_rollups.resource_name = #{'N' if sqlserver}'Anti-Spam1_D1')"
    end

    it "should test_fb11080" do
      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      or:
      - STARTS WITH:
          value: Anti
          field: Vm-name
      - INCLUDES:
          value: Includes
          field: Vm-v_annotation

      '

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should_not be_true
      sql.should be_nil

      exp = YAML.load '--- !ruby/object:MiqExpression
    exp:
      and:
      - STARTS WITH:
          value: Anti
          field: Vm-name
      - INCLUDES:
          value: Includes
          field: Vm-v_annotation

      '

      sql, incl, attrs = exp.to_sql
      attrs[:supported_by_sql].should_not be_true
      sql.should == "(vms.name LIKE 'Anti%')"
    end
  end
end
