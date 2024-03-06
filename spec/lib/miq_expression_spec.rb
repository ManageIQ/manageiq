RSpec.describe MiqExpression do
  describe '#reporting_available_fields' do
    let(:vm) { FactoryBot.create(:vm) }
    let!(:custom_attribute) { FactoryBot.create(:custom_attribute, :name => 'my_attribute_1', :resource => vm) }
    let(:extra_fields) do
      %w[start_date
         end_date
         interval_name
         display_range
         entity
         tag_name
         label_name
         id
         vm_id
         vm_name]
    end

    it 'lists custom attributes in ChargebackVm' do
      skip('removing of virtual custom attributes is needed to do first in other specs')

      displayed_columms = described_class.reporting_available_fields('ChargebackVm').map(&:second)
      expected_columns = (ChargebackVm.attribute_names - extra_fields).map { |x| "ChargebackVm-#{x}" }

      CustomAttribute.all.each do |custom_attribute|
        expected_columns.push("#{vm.class}-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}#{custom_attribute.name}")
      end
      expect(displayed_columms).to match_array(expected_columns)
    end

    context 'with ChargebackVm' do
      context 'with dynamic fields' do
        let(:volume_1) { FactoryBot.create(:cloud_volume, :volume_type => 'TYPE1') }
        let(:volume_2) { FactoryBot.create(:cloud_volume, :volume_type => 'TYPE2') }
        let(:volume_3) { FactoryBot.create(:cloud_volume, :volume_type => 'TYPE3') }
        let(:model)    { "ChargebackVm" }
        let(:volume_1_type_field_cost) { "#{model}-storage_allocated_#{volume_1.volume_type}_cost" }
        let(:volume_2_type_field_cost) { "#{model}-storage_allocated_#{volume_2.volume_type}_cost" }
        let(:volume_3_type_field_cost) { "#{model}-storage_allocated_#{volume_3.volume_type}_cost" }

        before do
          volume_1
          volume_2
        end

        it 'returns uncached actual fields also when dynamic fields chas been changed' do
          report_fields = described_class.reporting_available_fields(model).map(&:second)

          expect(report_fields).to include(volume_1_type_field_cost)
          expect(report_fields).to include(volume_2_type_field_cost)

          # case: change name
          volume_2.update!(:volume_type => 'NEW_TYPE_2')
          ChargebackVm.current_volume_types_clear_cache
          report_fields = described_class.reporting_available_fields(model).map(&:second)
          expect(report_fields).to include(volume_1_type_field_cost)
          expect(report_fields).not_to include(volume_2_type_field_cost) # old field

          # check existence of new name
          ChargebackVm.current_volume_types_clear_cache
          report_fields = described_class.reporting_available_fields(model).map(&:second)
          volume_2_type_field_cost = "#{model}-storage_allocated_#{volume_2.volume_type}_cost"
          expect(report_fields).to include(volume_1_type_field_cost)
          expect(report_fields).to include(volume_2_type_field_cost)

          # case: add volume_type
          volume_3
          ChargebackVm.current_volume_types_clear_cache
          report_fields = described_class.reporting_available_fields(model).map(&:second)
          expect(report_fields).to include(volume_1_type_field_cost)
          expect(report_fields).to include(volume_3_type_field_cost)

          # case: remove volume_types
          volume_2.destroy
          volume_3.destroy

          ChargebackVm.current_volume_types_clear_cache
          report_fields = described_class.reporting_available_fields(model).map(&:second)
          expect(report_fields).to include(volume_1_type_field_cost)
          expect(report_fields).not_to include(volume_2_type_field_cost)
          expect(report_fields).not_to include(volume_3_type_field_cost)
        end
      end
    end
  end

  describe "#valid?" do
    it "returns true for a valid flat expression" do
      expression = described_class.new("=" => {"field" => "Vm-name", "value" => "foo"})
      expect(expression).to be_valid
    end

    it "returns false for an invalid flat expression" do
      expression = described_class.new("=" => {"field" => "Vm-destroy", "value" => true})
      expect(expression).not_to be_valid
    end

    it "returns true if all the subexressions in an 'AND' expression are valid" do
      expression = described_class.new(
        "AND" => [
          {"=" => {"field" => "Vm-name", "value" => "foo"}},
          {"=" => {"field" => "Vm-description", "value" => "bar"}}
        ]
      )
      expect(expression).to be_valid
    end

    it "returns false if one of the subexressions in an 'AND' expression is invalid" do
      expression = described_class.new(
        "AND" => [
          {"=" => {"field" => "Vm-destroy", "value" => true}},
          {"=" => {"field" => "Vm-description", "value" => "bar"}}
        ]
      )
      expect(expression).not_to be_valid
    end

    it "returns true if all the subexressions in an 'OR' expression are valid" do
      expression = described_class.new(
        "OR" => [
          {"=" => {"field" => "Vm-name", "value" => "foo"}},
          {"=" => {"field" => "Vm-description", "value" => "bar"}}
        ]
      )
      expect(expression).to be_valid
    end

    it "returns false if one of the subexressions in an 'OR' expression is invalid" do
      expression = described_class.new(
        "OR" => [
          {"=" => {"field" => "Vm-destroy", "value" => true}},
          {"=" => {"field" => "Vm-description", "value" => "bar"}}
        ]
      )
      expect(expression).not_to be_valid
    end

    it "returns true if the subexression in a 'NOT' expression is valid" do
      expression1 = described_class.new("NOT" => {"=" => {"field" => "Vm-name", "value" => "foo"}})
      expression2 = described_class.new("!" => {"=" => {"field" => "Vm-name", "value" => "foo"}})
      expect([expression1, expression2]).to all(be_valid)
    end

    it "returns false if the subexression in a 'NOT' expression is invalid" do
      expression1 = described_class.new("NOT" => {"=" => {"field" => "Vm-destroy", "value" => true}})
      expression2 = described_class.new("!" => {"=" => {"field" => "Vm-destroy", "value" => true}})
      expect(expression1).not_to be_valid
      expect(expression2).not_to be_valid
    end

    it "returns true if the subexpressions in a 'FIND'/'checkall' expression are all valid" do
      expression = described_class.new(
        "FIND" => {
          "search"   => {"=" => {"field" => "Host.filesystems-name", "value" => "/etc/passwd"}},
          "checkall" => {"=" => {"field" => "Host.filesystems-permissions", "value" => "0644"}}
        }
      )
      expect(expression).to be_valid
    end

    it "returns false if a subexpression in a 'FIND'/'checkall' expression is invalid" do
      expression1 = described_class.new(
        "FIND" => {
          "search"   => {"=" => {"field" => "Host.filesystems-destroy", "value" => true}},
          "checkall" => {"=" => {"field" => "Host.filesystems-permissions", "value" => "0644"}}
        }
      )
      expression2 = described_class.new(
        "FIND" => {
          "search"   => {"=" => {"field" => "Host.filesystems-name", "value" => "/etc/passwd"}},
          "checkall" => {"=" => {"field" => "Host.filesystems-destroy", "value" => true}}
        }
      )
      expect(expression1).not_to be_valid
      expect(expression2).not_to be_valid
    end

    it "returns true if the subexpressions in a 'FIND'/'checkany' expression are all valid" do
      expression = described_class.new(
        "FIND" => {
          "search"   => {"=" => {"field" => "Host.filesystems-name", "value" => "/etc/passwd"}},
          "checkany" => {"=" => {"field" => "Host.filesystems-permissions", "value" => "0644"}}
        }
      )
      expect(expression).to be_valid
    end

    it "returns false if a subexpression in a 'FIND'/'checkany' expression is invalid" do
      expression1 = described_class.new(
        "FIND" => {
          "search"   => {"=" => {"field" => "Host.filesystems-destroy", "value" => true}},
          "checkany" => {"=" => {"field" => "Host.filesystems-permissions", "value" => "0644"}}
        }
      )
      expression2 = described_class.new(
        "FIND" => {
          "search"   => {"=" => {"field" => "Host.filesystems-name", "value" => "/etc/passwd"}},
          "checkany" => {"=" => {"field" => "Host.filesystems-destroy", "value" => true}}
        }
      )
      expect(expression1).not_to be_valid
      expect(expression2).not_to be_valid
    end

    it "returns true if the subexpressions in a 'FIND'/'checkcount' expression are all valid" do
      expression = described_class.new(
        "FIND" => {
          "search"     => {"IS NOT EMPTY" => {"field" => "Vm.snapshots-name"}},
          "checkcount" => {">" => {"field" => "<count>", "value" => 0}}
        }
      )
      expect(expression).to be_valid
    end

    it "returns false if a subexpression in a 'FIND'/'checkcount' expression is invalid" do
      expression = described_class.new(
        "FIND" => {
          "search"     => {"=" => {"field" => "Vm.snapshots-destroy"}},
          "checkcount" => {">" => {"field" => "<count>", "value" => 0}}
        }
      )
      expect(expression).not_to be_valid
    end
  end

  describe "#preprocess_exp!" do
    it "convert size value in units to integer for comparasing operators on integer field" do
      expession_hash = {"=" => {"field" => "Vm-allocated_disk_storage", "value" => "5.megabytes"}}
      expession = MiqExpression.new(expession_hash)
      exp, _ = expession.preprocess_exp!(expession_hash)
      expect(exp.values.first["value"]).to eq("5.megabyte".to_i_with_method)

      expession_hash = {">" => {"field" => "Vm-allocated_disk_storage", "value" => "5.kilobytes"}}
      expession = MiqExpression.new(expession_hash)
      exp, _ = expession.preprocess_exp!(expession_hash)
      expect(exp.values.first["value"]).to eq("5.kilobytes".to_i_with_method)

      expession_hash = {"<" => {"field" => "Vm-allocated_disk_storage", "value" => "2.terabytes"}}
      expession = MiqExpression.new(expession_hash)
      exp, _ = expession.preprocess_exp!(expession_hash)
      expect(exp.values.first["value"]).to eq(2.terabytes.to_i_with_method)
    end
  end

  describe "#reduce_exp" do
    let(:sql_field)  { {"=" => {"field" => "Vm-name", "value" => "foo"}.freeze}.freeze }
    let(:ruby_field) { {"=" => {"field" => "Vm-platform", "value" => "bar"}.freeze}.freeze }

    context "mode: :sql" do
      it "(sql AND ruby) => (sql)" do
        expect(sql_pruned_exp("AND" => [sql_field, ruby_field.clone])).to eq(sql_field)
      end

      it "(ruby AND ruby) => ()" do
        expect(sql_pruned_exp("AND" => [ruby_field.clone, ruby_field.clone])).to be_nil
      end

      it "(sql OR sql) => (sql OR sql)" do
        expect(sql_pruned_exp("OR" => [sql_field, sql_field])).to eq("OR" => [sql_field, sql_field])
      end

      it "(sql OR ruby) => ()" do
        expect(sql_pruned_exp("OR" => [sql_field, ruby_field])).to be_nil
      end

      it "(ruby OR ruby) => ()" do
        expect(sql_pruned_exp("OR" => [ruby_field.clone, ruby_field.clone].deep_clone)).to be_nil
      end

      it "!(sql OR ruby) => (!(sql) AND !(ruby)) => !(sql)" do
        expect(sql_pruned_exp("NOT" => {"OR" => [sql_field, ruby_field.clone]})).to eq("NOT" => sql_field)
      end

      it "!(sql AND ruby) => (!(sql) OR !(ruby)) => nil" do
        expect(sql_pruned_exp("NOT" => {"AND" => [sql_field, ruby_field.clone]})).to be_nil
      end
    end

    context "mode: ruby" do
      it "(sql) => ()" do
        expect(ruby_pruned_exp(sql_field.clone)).to be_nil
      end

      it "(ruby) => (ruby)" do
        expect(ruby_pruned_exp(ruby_field.clone)).to eq(ruby_field)
      end

      it "(sql and sql) => ()" do
        expect(ruby_pruned_exp("AND" => [sql_field.clone, sql_field.clone])).to be_nil
      end

      it "(sql and ruby) => (ruby)" do
        expect(ruby_pruned_exp("AND" => [sql_field.clone, ruby_field.clone])).to eq(ruby_field)
      end

      it "(ruby or ruby) => (ruby or ruby)" do
        expect(ruby_pruned_exp("OR" => [ruby_field.clone, ruby_field.clone])).to eq("OR" => [ruby_field, ruby_field])
      end

      it "(sql or sql) => ()" do
        expect(ruby_pruned_exp("OR" => [sql_field.clone, sql_field.clone])).to be_nil
      end

      it "(sql or ruby) => (sql or ruby)" do
        expect(ruby_pruned_exp("OR" => [ruby_field.clone, sql_field.clone])).to eq("OR" => [ruby_field, sql_field])
      end

      it "(ruby or ruby) => (ruby or ruby)" do
        expect(ruby_pruned_exp("OR" => [ruby_field.clone, ruby_field.clone])).to eq("OR" => [ruby_field, ruby_field])
      end

      it "(sql AND sql) or ruby => keep all expressions" do
        expect(ruby_pruned_exp("OR" => [{"AND" => [sql_field.clone, sql_field.clone]}, ruby_field.clone])).to eq("OR" => [{"AND" => [sql_field, sql_field]}, ruby_field])
      end

      # ensuring that the OR/AND is treating each sub expression independently
      # it was getting this wrong
      it "(sql or sql) and ruby => ruby" do
        expect(ruby_pruned_exp("AND" => [{"OR" => [sql_field.clone, sql_field.clone]}, ruby_field.clone])).to eq(ruby_field)
      end

      it "ruby and (sql or sql) => ruby" do
        expect(ruby_pruned_exp("AND" => [ruby_field.clone, {"OR" => [sql_field.clone, sql_field.clone]}])).to eq(ruby_field)
      end

      it "!(ruby) => keep all expressions" do
        exp1 = {"=" => {"field" => "Vm-platform", "value" => "foo"}}
        ruby = MiqExpression.new("NOT" => exp1).to_ruby(:prune_sql => true)
        expect(ruby).to eq("!(<value ref=vm, type=string>/virtual/platform</value> == \"foo\")")
      end

      it "!(sql OR ruby) => (!(sql) AND !(ruby)) => !(ruby)" do
        expect(ruby_pruned_exp("NOT" => {"OR" => [sql_field, ruby_field.clone]})).to eq("NOT" => ruby_field)
      end

      it "!(sql AND ruby) => (!(sql) OR !(ruby)) => !(sql AND ruby)" do
        expect(ruby_pruned_exp("NOT" => {"AND" => [sql_field, ruby_field.clone]})).to eq("NOT" => {"AND" => [sql_field, ruby_field]})
      end
    end
  end

  describe "#to_sql" do
    it "returns nil if SQL generation for that expression is not supported" do
      sql, * = MiqExpression.new("=" => {"field" => "Service-custom_1", "value" => ""}).to_sql
      expect(sql).to be_nil
    end

    it "does not raise error and returns nil if SQL generation for expression is not supported and 'token' key present in expression's Hash" do
      sql, * = MiqExpression.new("=" => {"field" => "Service-custom_1", "value" => ""}, :token => 1).to_sql
      expect(sql).to be_nil
    end

    it "does not raise error for SQL generation if expression has a count in it" do
      sql, _ = MiqExpression.new("AND" => [{"=" => {"field" => "Vm-name", "value" => "foo"}}, {"=" => {"count" => "Vm.snapshots", "value" => "1"}}]).to_sql
      expect(sql).to eq("\"vms\".\"name\" = 'foo'")
    end

    it "generates the SQL for an = expression if SQL generation for expression supported and 'token' key present in expression's Hash" do
      sql, * = MiqExpression.new("=" => {"field" => "Vm-name", "value" => "foo"}, :token => 1).to_sql
      expect(sql).to eq("\"vms\".\"name\" = 'foo'")
    end

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

    it "generates the SQL for a = expression with expression as a value" do
      sql, * = MiqExpression.new("=" => {"field" => "Vm-name", "value" => "Vm-name"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" = \"vms\".\"name\"")
    end

    it "will handle values that look like they contain MiqExpression-encoded constants but cannot be loaded" do
      sql, * = described_class.new("=" => {"field" => "Vm-name", "value" => "VM-name"}).to_sql
      expect(sql).to eq(%q("vms"."name" = 'VM-name'))
    end

    it "generates the SQL for a < expression" do
      sql, * = described_class.new("<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" < 2")
    end

    it "generates the SQL for a < expression with expression as a value" do
      sql, * = described_class.new("<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" < \"hardwares\".\"cpu_sockets\"")
    end

    it "generates the SQL for a <= expression" do
      sql, * = described_class.new("<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" <= 2")
    end

    it "generates the SQL for a <= expression with expression as a value" do
      sql, * = described_class.new("<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" <= \"hardwares\".\"cpu_sockets\"")
    end

    it "generates the SQL for a > expression" do
      sql, * = described_class.new(">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" > 2")
    end

    it "generates the SQL for a > expression with expression as a value" do
      sql, * = described_class.new(">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" > \"hardwares\".\"cpu_sockets\"")
    end

    it "generates the SQL for a >= expression" do
      sql, * = described_class.new(">=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" >= 2")
    end

    it "generates the SQL for a >= expression with expression as a value" do
      sql, * = described_class.new(">=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_sql
      expect(sql).to eq("\"hardwares\".\"cpu_sockets\" >= \"hardwares\".\"cpu_sockets\"")
    end

    it "generates the SQL for a != expression" do
      sql, * = described_class.new("!=" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" != 'foo'")
    end

    it "generates the SQL for a != expression with expression as a value" do
      sql, * = described_class.new("!=" => {"field" => "Vm-name", "value" => "Vm-name"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" != \"vms\".\"name\"")
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

    it "generates the SQL for an INCLUDES ANY with expression method" do
      sql, * = MiqExpression.new("INCLUDES ANY" => {"field" => "Vm-ipaddresses", "value" => "foo"}).to_sql
      expected_sql = <<~EXPECTED.split("\n").join(" ")
        1 = (SELECT 1
        FROM "hardwares"
        INNER JOIN "networks" ON "networks"."hardware_id" = "hardwares"."id"
        WHERE "hardwares"."vm_or_template_id" = "vms"."id"
        AND ("networks"."ipaddress" ILIKE '%foo%' OR "networks"."ipv6address" ILIKE '%foo%')
        LIMIT 1)
      EXPECTED
      expect(sql).to eq(expected_sql)
    end

    it "does not generate SQL for an INCLUDES ANY without an expression method" do
      sql, _, attrs = MiqExpression.new("INCLUDES ANY" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to be nil
      expect(attrs).to eq(:supported_by_sql => false)
    end

    it "does not generate SQL for an INCLUDES ALL without an expression method" do
      sql, _, attrs = MiqExpression.new("INCLUDES ALL" => {"field" => "Vm-ipaddresses", "value" => "foo"}).to_sql
      expect(sql).to be nil
      expect(attrs).to eq(:supported_by_sql => false)
    end

    it "does not generate SQL for an INCLUDES ONLY without an expression method" do
      sql, _, attrs = MiqExpression.new("INCLUDES ONLY" => {"field" => "Vm-ipaddresses", "value" => "foo"}).to_sql
      expect(sql).to be nil
      expect(attrs).to eq(:supported_by_sql => false)
    end

    it "generates the SQL for an AND expression" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-name", "value" => "bar"}}
      sql, * = MiqExpression.new("AND" => [exp1, exp2]).to_sql
      expect(sql).to eq("(\"vms\".\"name\" LIKE 'foo%' AND \"vms\".\"name\" LIKE '%bar')")
    end

    # these overlap the preprocessor tests
    it "generates the SQL for an AND expression where only one is supported by SQL" do
      exp1 = {"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}
      exp2 = {"ENDS WITH" => {"field" => "Vm-platform", "value" => "bar"}}
      sql, * = MiqExpression.new("AND" => [exp1, exp2]).to_sql
      expect(sql).to eq("\"vms\".\"name\" LIKE 'foo%'")
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
      expect(sql).to eq(%q(("vms"."name" LIKE 'foo%' OR "vms"."name" LIKE '%bar')))
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

    context "nested expressions" do
      it "properly groups the items in an AND/OR expression" do
        exp = {"AND" => [{"EQUAL" => {"field" => "Vm-power_state", "value" => "on"}},
                         {"OR" => [{"EQUAL" => {"field" => "Vm-name", "value" => "foo"}},
                                   {"EQUAL" => {"field" => "Vm-name", "value" => "bar"}}]}]}
        sql, * = described_class.new(exp).to_sql
        expect(sql).to eq(%q(("vms"."power_state" = 'on' AND ("vms"."name" = 'foo' OR "vms"."name" = 'bar'))))
      end

      it "properly groups the items in an OR/AND expression" do
        exp = {"OR" => [{"EQUAL" => {"field" => "Vm-power_state", "value" => "on"}},
                        {"AND" => [{"EQUAL" => {"field" => "Vm-name", "value" => "foo"}},
                                   {"EQUAL" => {"field" => "Vm-name", "value" => "bar"}}]}]}
        sql, * = described_class.new(exp).to_sql
        expect(sql).to eq(%q(("vms"."power_state" = 'on' OR ("vms"."name" = 'foo' AND "vms"."name" = 'bar'))))
      end

      it "properly groups the items in an OR/OR expression" do
        exp = {"OR" => [{"EQUAL" => {"field" => "Vm-power_state", "value" => "on"}},
                        {"OR" => [{"EQUAL" => {"field" => "Vm-name", "value" => "foo"}},
                                  {"EQUAL" => {"field" => "Vm-name", "value" => "bar"}}]}]}
        sql, * = described_class.new(exp).to_sql
        expect(sql).to eq(%q(("vms"."power_state" = 'on' OR ("vms"."name" = 'foo' OR "vms"."name" = 'bar'))))
      end
    end

    it "generates the SQL for a NOT expression" do
      sql, * = MiqExpression.new("NOT" => {"=" => {"field" => "Vm-name", "value" => "foo"}}).to_sql
      expect(sql).to eq("NOT (\"vms\".\"name\" = 'foo')")
    end

    it "generates the SQL for a ! expression" do
      sql, * = MiqExpression.new("!" => {"=" => {"field" => "Vm-name", "value" => "foo"}}).to_sql
      expect(sql).to eq("NOT (\"vms\".\"name\" = 'foo')")
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

    it "generates the SQL for a CONTAINS expression with has_many field" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.guest_applications-name", "value" => "foo"}).to_sql
      expected = "\"vms\".\"id\" IN (SELECT \"vms\".\"id\" FROM \"vms\" INNER JOIN \"guest_applications\" ON " \
                 "\"guest_applications\".\"vm_or_template_id\" = \"vms\".\"id\" WHERE \"guest_applications\".\"name\" = 'foo')"
      expect(sql).to eq(expected)
    end

    it "generates the SQL for a CONTAINS expression with association.association-field" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.guest_applications.host-name", "value" => "foo"}).to_sql
      rslt = "\"vms\".\"id\" IN (SELECT \"vms\".\"id\" FROM \"vms\" INNER JOIN \"guest_applications\" ON \"guest_applications\".\"vm_or_template_id\" = \"vms\".\"id\" INNER JOIN \"hosts\" ON \"hosts\".\"id\" = \"guest_applications\".\"host_id\" WHERE \"hosts\".\"name\" = 'foo')"
      expect(sql).to eq(rslt)
    end

    it "generates the SQL for a CONTAINS expression with belongs_to field" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.host-name", "value" => "foo"}).to_sql
      rslt = "\"vms\".\"id\" IN (SELECT \"vms\".\"id\" FROM \"vms\" INNER JOIN \"hosts\" ON \"hosts\".\"id\" = \"vms\".\"host_id\" WHERE \"hosts\".\"name\" = 'foo')"
      expect(sql).to eq(rslt)
    end

    it "generates the SQL for multi level contains with a scope" do
      sql, _ = MiqExpression.new("CONTAINS" => {"field" => "ExtManagementSystem.clustered_hosts.operating_system-name", "value" => "RHEL"}).to_sql
      rslt = "\"ext_management_systems\".\"id\" IN (SELECT \"ext_management_systems\".\"id\" FROM \"ext_management_systems\" " \
             "INNER JOIN \"hosts\" ON \"hosts\".\"ems_cluster_id\" IS NOT NULL AND \"hosts\".\"ems_id\" = \"ext_management_systems\".\"id\" " \
             "INNER JOIN \"operating_systems\" ON \"operating_systems\".\"host_id\" = \"hosts\".\"id\" " \
             "WHERE \"operating_systems\".\"name\" = 'RHEL')"
      expect(sql).to eq(rslt)
    end

    it "generates the SQL for field belongs to 'has_and_belongs_to_many' association" do
      sql, _ = MiqExpression.new("CONTAINS" => {"field" => "ManageIQ::Providers::InfraManager::Vm.storages-name", "value" => "abc"}).to_sql
      rslt = "\"vms\".\"id\" IN (SELECT \"vms\".\"id\" FROM \"vms\" " \
             "INNER JOIN \"storages_vms_and_templates\" ON \"storages_vms_and_templates\".\"vm_or_template_id\" = \"vms\".\"id\" " \
             "INNER JOIN \"storages\" ON \"storages\".\"id\" = \"storages_vms_and_templates\".\"storage_id\" " \
             "WHERE \"storages\".\"name\" = 'abc')"
      expect(sql).to eq(rslt)
    end

    it "can't generate the SQL for a CONTAINS expression virtualassociation" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.processes-name", "value" => "foo"}).to_sql
      expect(sql).to be_nil
    end

    it "can't generate the SQL for a CONTAINS expression with [association.virtualassociation]" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.evm_owner.active_vms-name", "value" => "foo"}).to_sql
      expect(sql).to be_nil
    end

    it "can't generate the SQL for a CONTAINS expression with invalid associations" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.users.active_vms-name", "value" => "foo"}).to_sql
      expect(sql).to be_nil
    end

    it "generates the SQL for a CONTAINS expression with field containing a scope" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm.users-name", "value" => "foo"}).to_sql
      expected = <<-EXPECTED.split("\n").map(&:strip).join(" ")
        "vms"."id" IN (SELECT "vms"."id"
                       FROM "vms"
                       INNER JOIN "accounts" ON "accounts"."accttype" = 'user'
                              AND "accounts"."vm_or_template_id" = "vms"."id"
                       WHERE "accounts"."name" = 'foo')
      EXPECTED
      expect(sql).to eq(expected)
    end

    it "generates the SQL for a CONTAINS in the main table" do
      sql, * = MiqExpression.new("CONTAINS" => {"field" => "Vm-name", "value" => "foo"}).to_sql
      expect(sql).to eq("\"vms\".\"name\" = 'foo'")
    end

    it "generates the SQL for a CONTAINS expression with tag" do
      tag = FactoryBot.create(:tag, :name => "/managed/operations/analysis_failed")
      vm = FactoryBot.create(:vm_vmware, :tags => [tag])
      exp = {"CONTAINS" => {"tag" => "VmInfra.managed-operations", "value" => "analysis_failed"}}
      sql, * = MiqExpression.new(exp).to_sql
      expect(sql).to eq("\"vms\".\"id\" IN (#{vm.id})")
    end

    it "generates the SQL for a CONTAINS expression with multi tier tag" do
      tag = FactoryBot.create(:tag, :name => "/managed/operations/analysis_failed")
      host = FactoryBot.create(:host_vmware, :tags => [tag])
      exp = {"CONTAINS" => {"tag" => "VmInfra.host.managed-operations", "value" => "analysis_failed"}}
      rslt = "\"vms\".\"id\" IN (SELECT \"vms\".\"id\" FROM \"vms\" INNER JOIN \"hosts\" ON \"hosts\".\"id\" = \"vms\".\"host_id\" WHERE \"hosts\".\"id\" IN (#{host.id}))"

      sql, * = MiqExpression.new(exp).to_sql
      expect(sql).to eq(rslt)
    end

    it "returns nil for a Registry expression" do
      exp = {"=" => {"regkey" => "test", "regval" => "value", "value" => "data"}}
      sql, * = MiqExpression.new(exp).to_sql
      expect(sql).to be_nil
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
          field: MiqGroup.vms-uncommitted_storage
          value: "false"
      '

      *, attrs = exp.to_sql
      expect(attrs[:supported_by_sql]).to eq(false)
    end

    context "date/time support" do
      it "generates the SQL for a = expression with a date field" do
        sql, * = described_class.new("=" => {"field" => "Vm-retires_on", "value" => "2016-01-01"}).to_sql
        expect(sql).to eq(%q("vms"."retires_on" = '2016-01-01 00:00:00'))
      end

      it "generates the SQL for an AFTER expression" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" > '2011-01-10 23:59:59.999999'")
      end

      it "generates the SQL for a BEFORE expression" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" < '2011-01-10 00:00:00'")
      end

      it "generates the SQL for an AFTER expression with date/time" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" > '2011-01-10 09:00:00'")
      end

      it "generates the SQL for a != expression with a date field" do
        sql, * = described_class.new("!=" => {"field" => "Vm-retires_on", "value" => "2016-01-01"}).to_sql
        expect(sql).to eq(%q("vms"."retires_on" != '2016-01-01 00:00:00'))
      end

      it "generates the SQL for an IS expression" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-10 00:00:00' AND '2011-01-10 23:59:59.999999'")
      end

      it "generates the SQL for a FROM expression" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-09 00:00:00' AND '2011-01-10 23:59:59.999999'")
      end

      it "generates the SQL for a FROM expression with MM/DD/YYYY dates" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-09 00:00:00' AND '2011-01-10 23:59:59.999999'")
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

      context "given a non-UTC timezone" do
        it "generates the SQL for a AFTER expression with a value of 'Yesterday' for a date field" do
          exp = described_class.new("AFTER" => {"field" => "Vm-retires_on", "value" => "Yesterday"})
          sql, * = exp.to_sql("Asia/Jakarta")
          expect(sql).to eq(%q("vms"."retires_on" > '2011-01-11 16:59:59.999999'))
        end

        it "generates the SQL for a BEFORE expression with a value of 'Yesterday' for a date field" do
          exp =  described_class.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "Yesterday"})
          sql, * = exp.to_sql("Asia/Jakarta")
          expect(sql).to eq(%q("vms"."retires_on" < '2011-01-10 17:00:00'))
        end

        it "generates the SQL for an IS expression with a value of 'Yesterday' for a date field" do
          exp = described_class.new("IS" => {"field" => "Vm-retires_on", "value" => "Yesterday"})
          sql, * = exp.to_sql("Asia/Jakarta")
          expect(sql).to eq(%q("vms"."retires_on" BETWEEN '2011-01-10 17:00:00' AND '2011-01-11 16:59:59.999999'))
        end

        it "generates the SQL for a FROM expression with a value of 'Yesterday'/'Today' for a date field" do
          exp = described_class.new("FROM" => {"field" => "Vm-retires_on", "value" => %w[Yesterday Today]})
          sql, * = exp.to_sql("Asia/Jakarta")
          expect(sql).to eq(%q("vms"."retires_on" BETWEEN '2011-01-10 17:00:00' AND '2011-01-12 16:59:59.999999'))
        end
      end

      it "generates the SQL for an AFTER expression with an 'n Days Ago' value for a date field" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" > '2011-01-09 23:59:59.999999'")
      end

      it "generates the SQL for an AFTER expression with an 'n Days Ago' value for a datetime field" do
        exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" > '2011-01-09 23:59:59.999999'")
      end

      it "generates the SQL for a BEFORE expression with an 'n Days Ago' value for a date field" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" < '2011-01-09 00:00:00'")
      end

      it "generates the SQL for a BEFORE expression with an 'n Days Ago' value for a datetime field" do
        exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" < '2011-01-09 00:00:00'")
      end

      it "generates the SQL for a FROM expression with a 'Last Hour'/'This Hour' value for a datetime field" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-11 16:00:00' AND '2011-01-11 17:59:59.999999'")
      end

      it "generates the SQL for a FROM expression with a 'Last Week'/'Last Week' value for a date field" do
        exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-03 00:00:00' AND '2011-01-09 23:59:59.999999'")
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
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-11 00:00:00' AND '2011-01-11 23:59:59.999999'")
      end

      it "generates the SQL for an IS expression with an 'n Hours Ago' value for a date field" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"retires_on\" BETWEEN '2011-01-11 14:00:00' AND '2011-01-11 14:59:59.999999'")
      end

      it "generates the SQL for an IS expression with an 'n Hours Ago' value for a datetime field" do
        exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
        sql, * = exp.to_sql
        expect(sql).to eq("\"vms\".\"last_scan_on\" BETWEEN '2011-01-11 14:00:00' AND '2011-01-11 14:59:59.999999'")
      end
    end

    describe "integration" do
      context "date/time support" do
        it "finds the correct instances for an gt expression with a dynamic integer field" do
          _vm1 = FactoryBot.create(:vm_vmware, :memory_reserve => 1, :cpu_reserve => 2)
          vm2 = FactoryBot.create(:vm_vmware, :memory_reserve => 2, :cpu_reserve => 1)
          filter = MiqExpression.new(">" => {"field" => "Vm-memory_reserve", "value" => "Vm-cpu_reserve"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an gt expression with a custom attribute dynamic integer field" do
          custom_attribute =  FactoryBot.create(:custom_attribute, :name => "example", :value => 10)
          vm1 = FactoryBot.create(:vm, :memory_reserve => 2)
          vm1.custom_attributes << custom_attribute
          _vm2 = FactoryBot.create(:vm, :memory_reserve => 0)
          name_of_attribute = "VmOrTemplate-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}example"
          filter = MiqExpression.new("<" => {"field" => "VmOrTemplate-memory_reserve", "value" => name_of_attribute})
          # This is basically calling Rbac.filtered_object
          # Leaving this as search to exercise the :skip_count methods
          result = Rbac.search(:targets => Vm, :filter => filter).first.first
          expect(filter.to_sql.last).to eq(:supported_by_sql => false)
          expect(result).to eq(vm1)
        end

        it "finds the correct instances for an AFTER expression with a datetime field" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 9:00")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 9:00:00.000001")
          filter = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11 9:00"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an IS EMPTY expression with a datetime field" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 9:01")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => nil)
          filter = MiqExpression.new("IS EMPTY" => {"field" => "Vm-last_scan_on"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an IS EMPTY expression with a date field" do
          _vm1 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-11")
          vm2 = FactoryBot.create(:vm_vmware, :retires_on => nil)
          filter = MiqExpression.new("IS EMPTY" => {"field" => "Vm-retires_on"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an IS NOT EMPTY expression with a datetime field" do
          vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 9:01")
          _vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => nil)
          filter = MiqExpression.new("IS NOT EMPTY" => {"field" => "Vm-last_scan_on"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm1])
        end

        it "finds the correct instances for an IS NOT EMPTY expression with a date field" do
          vm1 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-11")
          _vm2 = FactoryBot.create(:vm_vmware, :retires_on => nil)
          filter = MiqExpression.new("IS NOT EMPTY" => {"field" => "Vm-retires_on"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm1])
        end

        it "finds the correct instances for an IS expression with a date field" do
          _vm1 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-09")
          vm2 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-10")
          _vm3 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-11")
          filter = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an IS expression with a datetime field" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-10 23:59:59.999999")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 0:00")
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 23:59:59.999999")
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-12 0:00")
          filter = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with a datetime field, given date values" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2010-07-10 23:59:59.999999")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => "2010-07-11 00:00:00")
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => "2010-12-31 23:59:59.999999")
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-01 00:00:00")
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2010-07-11", "2010-12-31"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with a date field" do
          _vm1 = FactoryBot.create(:vm_vmware, :retires_on => "2010-07-10")
          vm2 = FactoryBot.create(:vm_vmware, :retires_on => "2010-07-11")
          vm3 = FactoryBot.create(:vm_vmware, :retires_on => "2010-12-31")
          _vm4 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-01")
          filter = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2010-07-11", "2010-12-31"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with a datetime field, given datetimes" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-09 16:59:59.999999")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-09 17:30:00")
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-10 23:30:59")
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-10 23:31:00")
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on",
                                                "value" => ["2011-01-09 17:00", "2011-01-10 23:30:59"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end
      end

      context "relative date/time support" do
        around { |example| Timecop.freeze("2011-01-11 17:30 UTC") { example.run } }

        it "finds the correct instances for an IS expression with 'Today'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.yesterday.end_of_day)
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.today)
          _vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.tomorrow.beginning_of_day)
          filter = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Today"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an IS expression with a datetime field and 'n Hours Ago'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.parse("13:59:59.999999"))
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.parse("14:00:00"))
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.parse("14:59:59.999999"))
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => Time.zone.parse("15:00:00"))
          filter = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for an IS expression with 'Last Month'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => (1.month.ago.beginning_of_month - 1.day).end_of_day)
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.beginning_of_month)
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.end_of_month)
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => (1.month.ago.end_of_month + 1.day).beginning_of_day)
          filter = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Month"})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with a date field and 'Last Week'" do
          _vm1 = FactoryBot.create(:vm_vmware, :retires_on => 1.week.ago.beginning_of_week - 1.day)
          vm2 = FactoryBot.create(:vm_vmware, :retires_on => 1.week.ago.beginning_of_week)
          vm3 = FactoryBot.create(:vm_vmware, :retires_on => 1.week.ago.end_of_week)
          _vm4 = FactoryBot.create(:vm_vmware, :retires_on => 1.week.ago.end_of_week + 1.day)
          filter = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with a datetime field and 'Last Week'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.ago.beginning_of_week - 1.second)
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.ago.beginning_of_week.beginning_of_day)
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.ago.end_of_week.end_of_day)
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.ago.end_of_week + 1.second)
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with 'Last Week' and 'This Week'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.ago.beginning_of_week - 1.second)
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.ago.beginning_of_week.beginning_of_day)
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.from_now.beginning_of_week - 1.second)
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.week.from_now.beginning_of_week.beginning_of_day)
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "This Week"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with 'n Months Ago'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => 2.months.ago.beginning_of_month - 1.second)
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => 2.months.ago.beginning_of_month.beginning_of_day)
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.end_of_month.end_of_day)
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.end_of_month + 1.second)
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "1 Month Ago"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with 'Last Month'" do
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.beginning_of_month - 1.second)
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.beginning_of_month.beginning_of_day)
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.end_of_month.end_of_day)
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => 1.month.ago.end_of_month + 1.second)
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Month", "Last Month"]})
          result = Vm.where(filter.to_sql.first)
          expect(result).to contain_exactly(vm2, vm3)
        end
      end

      context "timezone support" do
        it "finds the correct instances for a FROM expression with a datetime field and timezone" do
          timezone = "Eastern Time (US & Canada)"
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-09 21:59:59.999999")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-09 22:00:00")
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 04:30:59")
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 04:31:00")
          filter = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on",
                                                "value" => ["2011-01-09 17:00", "2011-01-10 23:30:59"]})
          result = Vm.where(filter.to_sql(timezone).first)
          expect(result).to contain_exactly(vm2, vm3)
        end

        it "finds the correct instances for a FROM expression with a date field and timezone" do
          timezone = "Eastern Time (US & Canada)"
          _vm1 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-09T23:59:59Z")
          vm2 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-10T06:30:00Z")
          _vm3 = FactoryBot.create(:vm_vmware, :retires_on => "2011-01-11T08:00:00Z")
          filter = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          result = Vm.where(filter.to_sql(timezone).first)
          expect(result).to eq([vm2])
        end

        it "finds the correct instances for an IS expression with timezone" do
          timezone = "Eastern Time (US & Canada)"
          _vm1 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 04:59:59.999999")
          vm2 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-11 05:00:00")
          vm3 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-12 04:59:59.999999")
          _vm4 = FactoryBot.create(:vm_vmware, :last_scan_on => "2011-01-12 05:00:00")
          filter = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-11"})
          result = Vm.where(filter.to_sql(timezone).first)
          expect(result).to contain_exactly(vm2, vm3)
        end
      end
    end

    context "caching" do
      it "clears caching if prune_sql value changes" do
        exp = MiqExpression.new({"=" => {"field" => "Vm-name", "value" => "foo"}})
        expect(exp.to_ruby(:prune_sql => true)).not_to eq(exp.to_ruby(:prune_sql => false))
      end
    end
  end

  describe "#lenient_evaluate" do
    describe "integration" do
      it "with a find/checkany expression" do
        host1, host2, host3, host4, host5, host6, host7, host8 = FactoryBot.create_list(:host, 8)
        FactoryBot.create(:vm_vmware, :host => host1, :description => "foo", :last_scan_on => "2011-01-08 16:59:59.999999")
        FactoryBot.create(:vm_vmware, :host => host2, :description => nil, :last_scan_on => "2011-01-08 16:59:59.999999")
        FactoryBot.create(:vm_vmware, :host => host3, :description => "bar", :last_scan_on => "2011-01-08 17:00:00")
        FactoryBot.create(:vm_vmware, :host => host4, :description => nil, :last_scan_on => "2011-01-08 17:00:00")
        FactoryBot.create(:vm_vmware, :host => host5, :description => "baz", :last_scan_on => "2011-01-09 23:30:59.999999")
        FactoryBot.create(:vm_vmware, :host => host6, :description => nil, :last_scan_on => "2011-01-09 23:30:59.999999")
        FactoryBot.create(:vm_vmware, :host => host7, :description => "qux", :last_scan_on => "2011-01-09 23:31:00")
        FactoryBot.create(:vm_vmware, :host => host8, :description => nil, :last_scan_on => "2011-01-09 23:31:00")
        filter = MiqExpression.new(
          "FIND" => {
            "checkany" => {"FROM" => {"field" => "Host.vms-last_scan_on",
                                      "value" => ["2011-01-08 17:00", "2011-01-09 23:30:59"]}},
            "search"   => {"IS NOT NULL" => {"field" => "Host.vms-description"}}})
        result = Host.all.to_a.select { |rec| filter.lenient_evaluate(rec) }
        expect(result).to contain_exactly(host3, host5)
      end

      it "with a find/checkall expression" do
        host1, host2, host3, host4, host5 = FactoryBot.create_list(:host, 5)

        FactoryBot.create(:vm_vmware, :host => host1, :description => "foo", :last_scan_on => "2011-01-08 16:59:59.999999")

        FactoryBot.create(:vm_vmware, :host => host2, :description => "bar", :last_scan_on => "2011-01-08 17:00:00")
        FactoryBot.create(:vm_vmware, :host => host2, :description => "baz", :last_scan_on => "2011-01-09 23:30:59.999999")

        FactoryBot.create(:vm_vmware, :host => host3, :description => "qux", :last_scan_on => "2011-01-08 17:00:00")
        FactoryBot.create(:vm_vmware, :host => host3, :description => nil, :last_scan_on => "2011-01-09 23:30:59.999999")

        FactoryBot.create(:vm_vmware, :host => host4, :description => nil, :last_scan_on => "2011-01-08 17:00:00")
        FactoryBot.create(:vm_vmware, :host => host4, :description => "quux", :last_scan_on => "2011-01-09 23:30:59.999999")

        FactoryBot.create(:vm_vmware, :host => host5, :description => "corge", :last_scan_on => "2011-01-09 23:31:00")

        filter = MiqExpression.new(
          "FIND" => {
            "search"   => {"FROM" => {"field" => "Host.vms-last_scan_on",
                                      "value" => ["2011-01-08 17:00", "2011-01-09 23:30:59"]}},
            "checkall" => {"IS NOT NULL" => {"field" => "Host.vms-description"}}}
        )
        result = Host.all.to_a.select { |rec| filter.lenient_evaluate(rec) }
        expect(result).to eq([host2])
      end

      it "cannot execute non-attribute methods on target objects" do
        vm = FactoryBot.create(:vm_vmware)

        expect do
          described_class.new("=" => {"field" => "Vm-destroy", "value" => true}).lenient_evaluate(vm)
        end.not_to change(Vm, :count)
      end
    end
  end

  describe "#to_ruby" do
    it "generates the ruby for a = expression with count" do
      actual = described_class.new("=" => {"count" => "Vm.snapshots", "value" => "1"}).to_ruby
      expected = "<count ref=vm>/virtual/snapshots</count> == 1"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a = expression with regkey" do
      actual = described_class.new("=" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}).to_ruby
      expected = "<registry>foo : bar</registry> == \"baz\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a < expression with hash context" do
      actual = described_class.new({"<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}, "hash").to_ruby
      expected = "<value type=integer>hardware.cpu_sockets</value> < 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a < expression with count" do
      actual = described_class.new("<" => {"count" => "Vm.snapshots", "value" => "2"}).to_ruby
      expected = "<count ref=vm>/virtual/snapshots</count> < 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a > expression with hash context" do
      actual = described_class.new({">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}, "hash").to_ruby
      expected = "<value type=integer>hardware.cpu_sockets</value> > 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a > expression with count" do
      actual = described_class.new(">" => {"count" => "Vm.snapshots", "value" => "2"}).to_ruby
      expected = "<count ref=vm>/virtual/snapshots</count> > 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a >= expression with hash context" do
      actual = described_class.new({">=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}, "hash").to_ruby
      expected = "<value type=integer>hardware.cpu_sockets</value> >= 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a >= expression with count" do
      actual = described_class.new(">=" => {"count" => "Vm.snapshots", "value" => "2"}).to_ruby
      expected = "<count ref=vm>/virtual/snapshots</count> >= 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a <= expression with hash context" do
      actual = described_class.new({"<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}, "hash").to_ruby
      expected = "<value type=integer>hardware.cpu_sockets</value> <= 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a <= expression with count" do
      actual = described_class.new("<=" => {"count" => "Vm.snapshots", "value" => "2"}).to_ruby
      expected = "<count ref=vm>/virtual/snapshots</count> <= 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a !=  expression with hash context" do
      actual = described_class.new({"!=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}, "hash").to_ruby
      expected = "<value type=integer>hardware.cpu_sockets</value> != 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a != expression with count" do
      actual = described_class.new("!=" => {"count" => "Vm.snapshots", "value" => "2"}).to_ruby
      expected = "<count ref=vm>/virtual/snapshots</count> != 2"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a BEFORE expression with hash context" do
      actual = described_class.new({"BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}}, "hash").to_ruby
      expected = "!(val=<value type=datetime>Vm.retires_on</value>&.to_time).nil? and val < Time.utc(2011,1,10,0,0,0)"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a AFTER expression with hash context" do
      actual = described_class.new({"AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}}, "hash").to_ruby
      expected = "!(val=<value type=datetime>Vm.retires_on</value>&.to_time).nil? and val > Time.utc(2011,1,10,23,59,59)"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a INCLUDES ALL expression with hash context" do
      actual = described_class.new(
        {"INCLUDES ALL" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, 1..4"}},
        "hash"
      ).to_ruby
      expected = "(<value type=numeric_set>Host.enabled_inbound_ports</value> & [1,2,3,4,22,427,5988,5989]) == [1,2,3,4,22,427,5988,5989]"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a INCLUDES ANY expression with hash context" do
      actual = described_class.new(
        {"INCLUDES ANY" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, 1..4"}},
        "hash"
      ).to_ruby
      expected = "([1,2,3,4,22,427,5988,5989] - <value type=numeric_set>Host.enabled_inbound_ports</value>) != [1,2,3,4,22,427,5988,5989]"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a INCLUDES ONLY expression with hash context" do
      actual = described_class.new(
        {"INCLUDES ONLY" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, 1..4"}},
        "hash"
      ).to_ruby
      expected = "(<value type=numeric_set>Host.enabled_inbound_ports</value> - [1,2,3,4,22,427,5988,5989]) == []"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a LIMITED TO expression with hash context" do
      actual = described_class.new(
        {"LIMITED TO" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, 1..4"}},
        "hash"
      ).to_ruby
      expected = "(<value type=numeric_set>Host.enabled_inbound_ports</value> - [1,2,3,4,22,427,5988,5989]) == []"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a LIKE expression with field" do
      actual = described_class.new("LIKE" => {"field" => "Vm-name", "value" => "foo"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /foo/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a LIKE expression with hash context" do
      actual = described_class.new({"LIKE" => {"field" => "Vm-name", "value" => "foo"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> =~ /foo/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a LIKE  expression with regkey" do
      actual = described_class.new("LIKE" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}).to_ruby
      expected = "<registry>foo : bar</registry> =~ /baz/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a NOT LIKE expression with field" do
      actual = described_class.new("NOT LIKE" => {"field" => "Vm-name", "value" => "foo"}).to_ruby
      expected = "!(<value ref=vm, type=string>/virtual/name</value> =~ /foo/)"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a NOT LIKE expression with hash context" do
      actual = described_class.new({"NOT LIKE" => {"field" => "Vm-name", "value" => "foo"}}, "hash").to_ruby
      expected = "!(<value type=string>Vm.name</value> =~ /foo/)"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a NOT LIKE expression with regkey" do
      actual = described_class.new("NOT LIKE" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}).to_ruby
      expected = "!(<registry>foo : bar</registry> =~ /baz/)"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a STARTS WITH expression with hash context with field" do
      actual = described_class.new({"STARTS WITH" => {"field" => "Vm-name", "value" => "foo"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> =~ /^foo/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a STARTS WITH expression with regkey" do
      actual = described_class.new("STARTS WITH" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}).to_ruby
      expected = "<registry>foo : bar</registry> =~ /^baz/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a ENDS WITH expression with hash context" do
      actual = described_class.new({"ENDS WITH" => {"field" => "Vm-name", "value" => "foo"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> =~ /foo$/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a ENDS WITH expression with regkey" do
      actual = described_class.new("ENDS WITH" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}).to_ruby
      expected = "<registry>foo : bar</registry> =~ /baz$/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a INCLUDES expression with hash context" do
      actual = described_class.new({"INCLUDES" => {"field" => "Vm-name", "value" => "foo"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> =~ /foo/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a INCLUDES expression with regkey" do
      actual = described_class.new("INCLUDES" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}).to_ruby
      expected = "<registry>foo : bar</registry> =~ /baz/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a REGULAR EXPRESSION MATCHES expression with regkey" do
      actual = described_class.new(
        "REGULAR EXPRESSION MATCHES" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}
      ).to_ruby
      expected = "<registry>foo : bar</registry> =~ /baz/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a REGULAR EXPRESSION DOES NOT MATCH expression with hash context" do
      actual = described_class.new(
        {"REGULAR EXPRESSION DOES NOT MATCH" => {"field" => "Vm-name", "value" => "foo"}},
        "hash"
      ).to_ruby
      expected = "<value type=string>Vm.name</value> !~ /foo/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a REGULAR EXPRESSION DOES NOT MATCH expression with regkey" do
      actual = described_class.new(
        "REGULAR EXPRESSION DOES NOT MATCH" => {"regkey" => "foo", "regval" => "bar", "value" => "baz"}
      ).to_ruby
      expected = "<registry>foo : bar</registry> !~ /baz/"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS NULL expression with hash context" do
      actual = described_class.new({"IS NULL" => {"field" => "Vm-name"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> == \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS NULL expression with regkey" do
      actual = described_class.new("IS NULL" => {"regkey" => "foo", "regval" => "bar"}).to_ruby
      expected = "<registry>foo : bar</registry> == \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS NOT NULL expression with hash context" do
      actual = described_class.new({"IS NOT NULL" => {"field" => "Vm-name"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> != \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS NOT NULL expression with regkey" do
      actual = described_class.new("IS NOT NULL" => {"regkey" => "foo", "regval" => "bar"}).to_ruby
      expected = "<registry>foo : bar</registry> != \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS EMPTY expression with hash context" do
      actual = described_class.new({"IS EMPTY" => {"field" => "Vm-name"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> == \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS EMPTY expression with regkey" do
      actual = described_class.new("IS EMPTY" => {"regkey" => "foo", "regval" => "bar"}).to_ruby
      expected = "<registry>foo : bar</registry> == \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS NOT EMPTY expression with hash context" do
      actual = described_class.new({"IS NOT EMPTY" => {"field" => "Vm-name"}}, "hash").to_ruby
      expected = "<value type=string>Vm.name</value> != \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a IS NOT EMPTY expression with regkey" do
      actual = described_class.new("IS NOT EMPTY" => {"regkey" => "foo", "regval" => "bar"}).to_ruby
      expected = "<registry>foo : bar</registry> != \"\""
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a CONTAINS expression with hash context" do
      actual = described_class.new(
        {"CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod"}},
        "hash"
      ).to_ruby
      expected = "<value type=string>managed.environment</value> CONTAINS \"\""
      expect(actual).to eq(expected)
    end

    it "generates the SQL for a < expression" do
      actual = described_class.new("<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_ruby
      expected = "<value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> < 2"
      expect(actual).to eq(expected)
    end

    it "generates the SQL for a < expression with dynamic value" do
      actual = described_class.new("<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_ruby
      expected = "<value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> < <value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value>"
      expect(actual).to eq(expected)
    end

    it "generates the SQL for a <= expression" do
      actual = described_class.new("<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}).to_ruby
      expected = "<value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> <= 2"
      expect(actual).to eq(expected)
    end

    it "generates the SQL for a <= expression with dynamic value" do
      actual = described_class.new("<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_ruby
      expected = "<value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> <= <value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value>"
      expect(actual).to eq(expected)
    end

    it "generates the SQL for a != expression" do
      actual = described_class.new("!=" => {"field" => "Vm-name", "value" => "foo"}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> != \"foo\""
      expect(actual).to eq(expected)
    end

    it "generates the SQL for a != expression with dynamic value" do
      actual = described_class.new("!=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "Vm.hardware-cpu_sockets"}).to_ruby
      expected = "<value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> != <value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value>"
      expect(actual).to eq(expected)
    end

    it "detects value empty array" do
      exp = MiqExpression.new("INCLUDES" => {"field" => "Vm-name", "value" => "[]"})
      expect(exp.to_ruby).to eq("<value ref=vm, type=string>/virtual/name</value> =~ /\\[\\]/")
    end

    it "raises error if expression contains ruby script" do
      exp = MiqExpression.new("RUBY" => {"field" => "Host-name", "value" => "puts 'Hello world!'"})
      expect { exp.to_ruby }.to raise_error(/operator 'RUBY' is not supported/)
    end

    it "ignores invalid values for a numeric_set in an = expression" do
      actual = described_class.new("=" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, foo, `echo 1000`.to_i, abc..123, 1..4"}).to_ruby
      expected = "<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> == [1,2,3,4,22,427,5988,5989]"
      expect(actual).to eq(expected)
    end

    it "ignores invalid values for a numeric_set in an INCLUDES ALL expression" do
      actual = described_class.new("INCLUDES ALL" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, foo, `echo 1000`.to_i, abc..123, 1..4"}).to_ruby
      expected = "(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> & [1,2,3,4,22,427,5988,5989]) == [1,2,3,4,22,427,5988,5989]"
      expect(actual).to eq(expected)
    end

    it "ignores invalid values for a numeric_set in an INCLUDES ANY expression" do
      actual = described_class.new("INCLUDES ANY" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, foo, `echo 1000`.to_i, abc..123, 1..4"}).to_ruby
      expected = "([1,2,3,4,22,427,5988,5989] - <value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value>) != [1,2,3,4,22,427,5988,5989]"
      expect(actual).to eq(expected)
    end

    it "ignores invalid values for a numeric_set in an INCLUDES ONLY expression" do
      actual = described_class.new("INCLUDES ONLY" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, foo, `echo 1000`.to_i, abc..123, 1..4"}).to_ruby
      expected = "(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [1,2,3,4,22,427,5988,5989]) == []"
      expect(actual).to eq(expected)
    end

    it "ignores invalid values for a numeric_set in an LIMITED TO expression" do
      actual = described_class.new("LIMITED TO" => {"field" => "Host-enabled_inbound_ports", "value" => "22, 427, 5988, 5989, foo, `echo 1000`.to_i, abc..123, 1..4"}).to_ruby
      expected = "(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [1,2,3,4,22,427,5988,5989]) == []"
      expect(actual).to eq(expected)
    end

    it "escapes forward slashes for values in REGULAR EXPRESSION MATCHES expressions" do
      value = "//; puts 'Hi, mom!';//"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\/; puts 'Hi, mom!';\\//"
      expect(actual).to eq(expected)
    end

    it "preserves the delimiters when escaping forward slashes in case-insensitive REGULAR EXPRESSION MATCHES expressions" do
      value = "//; puts 'Hi, mom!';//i"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\/; puts 'Hi, mom!';\\//i"
      expect(actual).to eq(expected)
    end

    it "escapes forward slashes for non-Regexp literal values in REGULAR EXPRESSION MATCHES expressions" do
      value = ".*/; puts 'Hi, mom!';/.*"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /.*\\/; puts 'Hi, mom!';\\/.*/"
      expect(actual).to eq(expected)
    end

    it "does not escape escaped forward slashes for values in REGULAR EXPRESSION MATCHES expressions" do
      value = "/foo/bar"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\/foo\\/bar/"
      expect(actual).to eq(expected)
    end

    it "handles arbitarily long escaping of forward " do
      value = "\\\\\\/foo\\\\\\/bar"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\/foo\\/bar/"
      expect(actual).to eq(expected)
    end

    it "escapes interpolation in REGULAR EXPRESSION MATCHES expressions" do
      value = "/\#{puts 'Hi, mom!'}/"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\\#{puts 'Hi, mom!'}/"
      expect(actual).to eq(expected)
    end

    it "handles arbitrarily long escaping of interpolation in REGULAR EXPRESSION MATCHES expressions" do
      value = "/\\\\\#{puts 'Hi, mom!'}/"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\\#{puts 'Hi, mom!'}/"
      expect(actual).to eq(expected)
    end

    it "escapes interpolation in non-Regexp literal values in REGULAR EXPRESSION MATCHES expressions" do
      value = "\#{puts 'Hi, mom!'}"
      actual = described_class.new("REGULAR EXPRESSION MATCHES" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> =~ /\\\#{puts 'Hi, mom!'}/"
      expect(actual).to eq(expected)
    end

    it "escapes forward slashes for values in REGULAR EXPRESSION DOES NOT MATCH expressions" do
      value = "//; puts 'Hi, mom!';//"
      actual = described_class.new("REGULAR EXPRESSION DOES NOT MATCH" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> !~ /\\/; puts 'Hi, mom!';\\//"
      expect(actual).to eq(expected)
    end

    it "preserves the delimiters when escaping forward slashes in case-insensitive REGULAR EXPRESSION DOES NOT MATCH expressions" do
      value = "//; puts 'Hi, mom!';//i"
      actual = described_class.new("REGULAR EXPRESSION DOES NOT MATCH" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> !~ /\\/; puts 'Hi, mom!';\\//i"
      expect(actual).to eq(expected)
    end

    it "escapes forward slashes for non-Regexp literal values in REGULAR EXPRESSION DOES NOT MATCH expressions" do
      value = ".*/; puts 'Hi, mom!';/.*"
      actual = described_class.new("REGULAR EXPRESSION DOES NOT MATCH" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> !~ /.*\\/; puts 'Hi, mom!';\\/.*/"
      expect(actual).to eq(expected)
    end

    it "does not escape escaped forward slashes for values in REGULAR EXPRESSION DOES NOT MATCH expressions" do
      value = "/foo/bar"
      actual = described_class.new("REGULAR EXPRESSION DOES NOT MATCH" => {"field" => "Vm-name", "value" => value}).to_ruby
      expected = "<value ref=vm, type=string>/virtual/name</value> !~ /\\/foo\\/bar/"
      expect(actual).to eq(expected)
    end

    # Note: To debug these tests, the following may be helpful:
    # puts "Expression Raw:      #{filter.exp.inspect}"
    # puts "Expression in Human: #{filter.to_human}"
    # puts "Expression in Ruby:  #{filter.to_ruby}"

    it "expands ranges with INCLUDES ALL" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ALL:
          field: Host-enabled_inbound_ports
          value: 22, 427, 5988, 5989, 1..4
      '
      expected = "(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> & [1,2,3,4,22,427,5988,5989]) == [1,2,3,4,22,427,5988,5989]"
      expect(filter.to_ruby).to eq(expected)
    end

    it "expands ranges with INCLUDES ANY" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ANY:
          field: Host-enabled_inbound_ports
          value: 22, 427, 5988, 5989, 1..4
      '

      expected = "([1,2,3,4,22,427,5988,5989] - <value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value>) != [1,2,3,4,22,427,5988,5989]"
      expect(filter.to_ruby).to eq(expected)
    end

    it "expands ranges with INCLUDES ONLY" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ONLY:
          field: Host-enabled_inbound_ports
          value: 22, 427, 5988, 5989, 1..4
      '

      expected = "(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [1,2,3,4,22,427,5988,5989]) == []"
      expect(filter.to_ruby).to eq(expected)
    end

    it "expands ranges with LIMITED TO" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        LIMITED TO:
          field: Host-enabled_inbound_ports
          value: 22, 427, 5988, 5989, 1..4
      '

      expected = "(<value ref=host, type=numeric_set>/virtual/enabled_inbound_ports</value> - [1,2,3,4,22,427,5988,5989]) == []"
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test string set expressions with EQUAL" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        "=":
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
      '

      expected = "<value ref=host, type=string_set>/virtual/service_names</value> == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']"
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test string set expressions with INCLUDES ALL" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ALL:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
      '

      expected = "(<value ref=host, type=string_set>/virtual/service_names</value> & ['ntpd','sshd','vmware-vpxa','vmware-webAccess']) == ['ntpd','sshd','vmware-vpxa','vmware-webAccess']"
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test string set expressions with INCLUDES ANY" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ANY:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa, vmware-webAccess"
      '

      expected = "(['ntpd','sshd','vmware-vpxa','vmware-webAccess'] - <value ref=host, type=string_set>/virtual/service_names</value>) != ['ntpd','sshd','vmware-vpxa','vmware-webAccess']"
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test string set expressions with INCLUDES ONLY" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        INCLUDES ONLY:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa"
      '

      expected = "(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []"
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test string set expressions with LIMITED TO" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        LIMITED TO:
          field: Host-service_names
          value: "ntpd, sshd, vmware-vpxa"
      '

      expected = "(<value ref=host, type=string_set>/virtual/service_names</value> - ['ntpd','sshd','vmware-vpxa']) == []"
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test string set expressions with FIND/checkall" do
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

      expected = '<find><search><value ref=host, type=text>/virtual/filesystems/name</value> == "/etc/passwd"</search><check mode=all><value ref=host, type=string>/virtual/filesystems/permissions</value> == "0644"</check></find>'
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test regexp with regex literal" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        REGULAR EXPRESSION MATCHES:
          field: Host-name
          value: /^[^.]*\.galaxy\..*$/
      '
      expect(filter.to_ruby).to eq('<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/')
    end

    it "should test regexp with string literal" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      exp:
        REGULAR EXPRESSION MATCHES:
          field: Host-name
          value: ^[^.]*\.galaxy\..*$
      '
      expect(filter.to_ruby).to eq('<value ref=host, type=string>/virtual/name</value> =~ /^[^.]*\.galaxy\..*$/')
    end

    it "should test regexp as part of a FIND/checkany expression" do
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

      expected = '<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == "true"</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> =~ /^.*SLP.*$/</check></find>'
      expect(filter.to_ruby).to eq(expected)
    end

    it "should test negative regexp with FIND/checkany expression" do
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

      expected = '<find><search><value ref=host, type=boolean>/virtual/firewall_rules/enabled</value> == "true"</search><check mode=any><value ref=host, type=string>/virtual/firewall_rules/name</value> !~ /^.*SLP.*$/</check></find>'
      expect(filter.to_ruby).to eq(expected)
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
    end

    it "should test numbers with commas with methods" do
      filter = YAML.load '--- !ruby/object:MiqExpression
      context_type:
      exp:
        ">=":
          field: Vm-used_disk_storage
          value: 1,000.megabytes
      '
      expect(filter.to_ruby).to eq('<value ref=vm, type=integer>/virtual/used_disk_storage</value> >= 1048576000')
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

    it "generates the ruby for an OR with a count" do
      actual = described_class.new("OR" => [{"=" => {"field" => "Vm-name", "value" => "foo"}}, {"=" => {"count" => "Vm.snapshots", "value" => "1"}}]).to_ruby
      expected = "(<value ref=vm, type=string>/virtual/name</value> == \"foo\" or <count ref=vm>/virtual/snapshots</count> == 1)"
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
                   "checkall" => {">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=all><value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> > 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkany" do
      actual = described_class.new(
        "FIND" => {"search"   => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkany" => {">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=any><value ref=vm, type=integer>/virtual/hardware/cpu_sockets</value> > 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount and =" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {"=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> == 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount and !=" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {"!=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> != 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount and <" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {"<" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> < 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount and >" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {">" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> > 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount and <=" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {"<=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> <= 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a FIND expression with checkcount and >=" do
      actual = described_class.new(
        "FIND" => {"search"     => {"=" => {"field" => "Vm-name", "value" => "foo"}},
                   "checkcount" => {">=" => {"field" => "Vm.hardware-cpu_sockets", "value" => "2"}}}
      ).to_ruby
      expected = "<find><search><value ref=vm, type=string>/virtual/name</value> == \"foo\"</search><check mode=count><count> >= 2</check></find>"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a KEY EXISTS expression" do
      actual = described_class.new("KEY EXISTS" => {"regkey" => "foo"}).to_ruby
      expected = "<registry key_exists=1, type=boolean>foo</registry>  == 'true'"
      expect(actual).to eq(expected)
    end

    it "generates the ruby for a VALUE EXISTS expression" do
      actual = described_class.new("VALUE EXISTS" => {"regkey" => "foo", "regval" => "bar"}).to_ruby
      expected = "<registry value_exists=1, type=boolean>foo : bar</registry>  == 'true'"
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
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val > Time.utc(2011,1,10,23,59,59)")
        end

        it "generates the ruby for a BEFORE expression with date value" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val < Time.utc(2011,1,10,0,0,0)")
        end

        it "generates the ruby for a AFTER expression with datetime value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val > Time.utc(2011,1,10,9,0,0)")
        end

        it "generates the ruby for a IS expression with date value" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)")
        end

        it "generates the ruby for a IS expression with datetime value" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)")
        end

        it "generates the ruby for a IS expression with hash context" do
          actual = described_class.new({"IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"}}, "hash").to_ruby
          expected = "!(val=<value type=datetime>Vm.retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)"
          expect(actual).to eq(expected)
        end

        it "generates the ruby for a FROM expression with date values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,9,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)")
        end

        it "generates the ruby for a FROM expression with date values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["01/09/2011", "01/10/2011"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,9,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)")
        end

        it "generates the ruby for a FROM expression with datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,8,0,0) and val <= Time.utc(2011,1,10,17,0,0)")
        end

        it "generates the ruby for a FROM expression with identical datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,0,0,0) and val <= Time.utc(2011,1,10,0,0,0)")
        end

        it "generates the ruby for a FROM expression with hash context" do
          actual = described_class.new(
            {"FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]}},
            "hash"
          ).to_ruby
          expected = "!(val=<value type=datetime>Vm.retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,9,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)"
          expect(actual).to eq(expected)
        end
      end

      context "static dates and times with a time zone" do
        let(:tz) { "Eastern Time (US & Canada)" }

        it "generates the ruby for a AFTER expression with date value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val > Time.utc(2011,1,11,4,59,59)")
        end

        it "generates the ruby for a BEFORE expression with date value" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val < Time.utc(2011,1,10,5,0,0)")
        end

        it "generates the ruby for a AFTER expression with datetime value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val > Time.utc(2011,1,10,14,0,0)")
        end

        it "generates the ruby for a AFTER expression with datetime value" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2011-01-10 9:00"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val > Time.utc(2011,1,10,14,0,0)")
        end

        it "generates the ruby for a IS expression wtih date value" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "2011-01-10"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,5,0,0) and val <= Time.utc(2011,1,11,4,59,59)")
        end

        it "generates the ruby for a FROM expression with date values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["2011-01-09", "2011-01-10"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,9,5,0,0) and val <= Time.utc(2011,1,11,4,59,59)")
        end

        it "generates the ruby for a FROM expression with datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 8:00", "2011-01-10 17:00"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,13,0,0) and val <= Time.utc(2011,1,10,22,0,0)")
        end

        it "generates the ruby for a FROM expression with identical datetime values" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2011-01-10 00:00", "2011-01-10 00:00"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,5,0,0) and val <= Time.utc(2011,1,10,5,0,0)")
        end
      end
    end

    context "relative date/time support" do
      around { |example| Timecop.freeze("2011-01-11 17:30 UTC") { example.run } }

      context "given a non-UTC timezone" do
        it "generates the SQL for a AFTER expression with a value of 'Yesterday' for a date field" do
          exp = described_class.new("AFTER" => {"field" => "Vm-retires_on", "value" => "Yesterday"})
          ruby, * = exp.to_ruby("Asia/Jakarta")
          expect(ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val > Time.utc(2011,1,11,16,59,59)")
        end

        it "generates the RUBY for a BEFORE expression with a value of 'Yesterday' for a date field" do
          exp = described_class.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "Yesterday"})
          ruby, * = exp.to_ruby("Asia/Jakarta")
          expect(ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val < Time.utc(2011,1,10,17,0,0)")
        end

        it "generates the RUBY for an IS expression with a value of 'Yesterday' for a date field" do
          exp = described_class.new("IS" => {"field" => "Vm-retires_on", "value" => "Yesterday"})
          ruby, * = exp.to_ruby("Asia/Jakarta")
          expect(ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,17,0,0) and val <= Time.utc(2011,1,11,16,59,59)")
        end

        it "generates the RUBY for a FROM expression with a value of 'Yesterday'/'Today' for a date field" do
          exp = described_class.new("FROM" => {"field" => "Vm-retires_on", "value" => %w[Yesterday Today]})
          ruby, * = exp.to_ruby("Asia/Jakarta")
          expect(ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,17,0,0) and val <= Time.utc(2011,1,12,16,59,59)")
        end
      end

      context "relative dates with no time zone" do
        it "generates the ruby for an AFTER expression with date value of n Days Ago" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val > Time.utc(2011,1,9,23,59,59)")
        end

        it "generates the ruby for an AFTER expression with datetime value of n Days ago" do
          exp = MiqExpression.new("AFTER" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val > Time.utc(2011,1,9,23,59,59)")
        end

        it "generates the ruby for a BEFORE expression with date value of n Days Ago" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-retires_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val < Time.utc(2011,1,9,0,0,0)")
        end

        it "generates the ruby for a BEFORE expression with datetime value of n Days Ago" do
          exp = MiqExpression.new("BEFORE" => {"field" => "Vm-last_scan_on", "value" => "2 Days Ago"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val < Time.utc(2011,1,9,0,0,0)")
        end

        it "generates the ruby for a FROM expression with datetime values of Last/This Hour" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,16,0,0) and val <= Time.utc(2011,1,11,17,59,59)")
        end

        it "generates the ruby for a FROM expression with date values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,0,0,0) and val <= Time.utc(2011,1,9,23,59,59)")
        end

        it "generates the ruby for a FROM expression with datetime values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,0,0,0) and val <= Time.utc(2011,1,9,23,59,59)")
        end

        it "generates the ruby for a FROM expression with datetime values of n Months Ago/Last Month" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2010,11,1,0,0,0) and val <= Time.utc(2010,12,31,23,59,59)")
        end

        it "generates the ruby for an IS expression with datetime value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,0,0,0) and val <= Time.utc(2011,1,9,23,59,59)")
        end

        it "generates the ruby for an IS expression with relative date with hash context" do
          actual = described_class.new({"IS" => {"field" => "Vm-retires_on", "value" => "Yesterday"}}, "hash").to_ruby
          expected = "!(val=<value type=datetime>Vm.retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,10,0,0,0) and val <= Time.utc(2011,1,10,23,59,59)"
          expect(actual).to eq(expected)
        end

        it "generates the ruby for an IS expression with date value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Last Week"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,0,0,0) and val <= Time.utc(2011,1,9,23,59,59)")
        end

        it "generates the ruby for a IS expression with date value of Today" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,0,0,0) and val <= Time.utc(2011,1,11,23,59,59)")
        end

        it "generates the ruby for an IS expression with date value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,14,0,0) and val <= Time.utc(2011,1,11,14,59,59)")
        end

        it "generates the ruby for a IS expression with datetime value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,14,0,0) and val <= Time.utc(2011,1,11,14,59,59)")
        end
      end

      context "relative time with a time zone" do
        let(:tz) { "Hawaii" }

        it "generates the ruby for a FROM expression with datetime value of Last/This Hour" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Hour", "This Hour"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,16,0,0) and val <= Time.utc(2011,1,11,17,59,59)")
        end

        it "generates the ruby for a FROM expression with date values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-retires_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,10,0,0) and val <= Time.utc(2011,1,10,9,59,59)")
        end

        it "generates the ruby for a FROM expression with datetime values of Last Week" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["Last Week", "Last Week"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,10,0,0) and val <= Time.utc(2011,1,10,9,59,59)")
        end

        it "generates the ruby for a FROM expression with datetime values of n Months Ago/Last Month" do
          exp = MiqExpression.new("FROM" => {"field" => "Vm-last_scan_on", "value" => ["2 Months Ago", "Last Month"]})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2010,11,1,10,0,0) and val <= Time.utc(2011,1,1,9,59,59)")
        end

        it "generates the ruby for an IS expression with datetime value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "Last Week"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,10,0,0) and val <= Time.utc(2011,1,10,9,59,59)")
        end

        it "generates the ruby for an IS expression with date value of Last Week" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Last Week"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,3,10,0,0) and val <= Time.utc(2011,1,10,9,59,59)")
        end

        it "generates the ruby for an IS expression with date value of Today" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "Today"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,10,0,0) and val <= Time.utc(2011,1,12,9,59,59)")
        end

        it "generates the ruby for an IS expression with date value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-retires_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/retires_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,14,0,0) and val <= Time.utc(2011,1,11,14,59,59)")
        end

        it "generates the ruby for an IS expression with datetime value of n Hours Ago" do
          exp = MiqExpression.new("IS" => {"field" => "Vm-last_scan_on", "value" => "3 Hours Ago"})
          expect(exp.to_ruby(tz)).to eq("!(val=<value ref=vm, type=datetime>/virtual/last_scan_on</value>&.to_time).nil? and val >= Time.utc(2011,1,11,14,0,0) and val <= Time.utc(2011,1,11,14,59,59)")
        end
      end
    end
  end

  describe ".numeric?" do
    it "should return true if digits separated by comma and false if another separator used" do
      expect(MiqExpression.numeric?('10000.55')).to be_truthy
      expect(MiqExpression.numeric?('10,000.55')).to be_truthy
      expect(MiqExpression.numeric?('10 000.55')).to be_falsey
    end

    it "should return true if there is method attached to number" do
      expect(MiqExpression.numeric?('2,555.hello')).to eq(false)
      expect(MiqExpression.numeric?('2,555.kilobytes')).to eq(true)
      expect(MiqExpression.numeric?('2,555.55.megabytes')).to eq(true)
    end
  end

  describe ".integer?" do
    it "should return true if digits separated by comma and false if another separator used" do
      expect(MiqExpression.integer?('2,555')).to eq(true)
      expect(MiqExpression.integer?('2 555')).to eq(false)
    end

    it "should return true if there is method attached to number" do
      expect(MiqExpression.integer?('2,555.kilobytes')).to eq(true)
      expect(MiqExpression.integer?('2,555.hello')).to eq(false)
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
      expect(cluster_sorted.map(&:first)).to include("Cluster : Total Number of Physical CPUs")
      expect(cluster_sorted.map(&:first)).to include("Cluster : Total Number of Logical CPUs")
      hardware_sorted = details.select { |d| d.first.starts_with?("Hardware") }.sort
      expect(hardware_sorted.map(&:first)).not_to include("Hardware : Logical Cpus")
    end

    it "should not contain duplicate tag fields" do
      # tags contain the root tenant's name
      Tenant.seed

      category = FactoryBot.create(:classification, :name => 'environment', :description => 'Environment')
      FactoryBot.create(:classification, :parent_id => category.id, :name => 'prod', :description => 'Production')
      tags = MiqExpression.model_details('Host',
                                         :typ             => 'tag',
                                         :include_model   => true,
                                         :include_my_tags => false,
                                         :userid          => 'admin')
      expect(tags.uniq.length).to eq(tags.length)
    end
  end

  context "._custom_details_for" do
    let(:klass)         { Vm }
    let(:vm)            { FactoryBot.create(:vm) }
    let!(:custom_attr1) { FactoryBot.create(:custom_attribute, :resource => vm, :name => "CATTR_1", :value => "Value 1") }
    let!(:custom_attr2) { FactoryBot.create(:custom_attribute, :resource => vm, :name => nil,       :value => "Value 2") }

    it "ignores custom_attibutes with a nil name" do
      expect(MiqExpression._custom_details_for("Vm", {})).to eq([["Custom Attribute: CATTR_1", "Vm-virtual_custom_attribute_CATTR_1"]])
    end

    let(:conatiner_image) { FactoryBot.create(:container_image) }

    let!(:custom_attribute_with_section_1) do
      FactoryBot.create(:custom_attribute, :resource => conatiner_image, :name => 'CATTR_3', :value => "Value 3",
                         :section => 'section_3')
    end

    let!(:custom_attribute_with_section_2) do
      FactoryBot.create(:custom_attribute, :resource => conatiner_image, :name => 'CATTR_3', :value => "Value 3",
                         :section => 'docker_labels')
    end

    it "returns human names of custom attributes with sections" do
      expected_result = [
        ['Docker Labels: CATTR_3', 'ContainerImage-virtual_custom_attribute_CATTR_3:SECTION:docker_labels'],
        ['Section 3: CATTR_3', 'ContainerImage-virtual_custom_attribute_CATTR_3:SECTION:section_3']
      ]

      expect(MiqExpression._custom_details_for("ContainerImage", {})).to match_array(expected_result)
    end

    context "model is ChargebackVm" do
      let(:vm) { FactoryBot.create(:vm) }
      let!(:custom_attribute_for_vm) { FactoryBot.create(:custom_attribute, :name => 'Application', :section => 'labels', :resource => vm) }

      it "returns human names of custom attributes with sections" do
        expected_result = [
          ['Labels: Application', 'ChargebackVm-virtual_custom_attribute_Application:SECTION:labels'],
          ['Custom Attribute: CATTR_1', 'ChargebackVm-virtual_custom_attribute_CATTR_1']
        ]

        expect(MiqExpression._custom_details_for("Vm", :model_for_column => "ChargebackVm")).to match_array(expected_result)
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
      expect(exp.to_human).to eq('FIND VM and Instance.Advanced Settings : ' \
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

        category = FactoryBot.create(:classification, :name => 'environment', :description => 'Environment')
        FactoryBot.create(:classification, :parent_id => category.id, :name => 'prod', :description => 'Production')
      end

      it "generates a human readable string for a TAG expression" do
        exp = MiqExpression.new("CONTAINS" => {"tag" => "Host.managed-environment", "value" => "prod"})
        expect(exp.to_human).to eq("Host.My Company Tags : Environment CONTAINS 'Production'")
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

  describe ".model_details" do
    before do
      # tags contain the root tenant's name
      Tenant.seed

      cat = FactoryBot.create(:classification,
                               :description  => "Auto Approve - Max CPU",
                               :name         => "prov_max_cpu",
                               :single_value => true,
                               :show         => true
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

    context "with :include_id_columns" do
      it "Vm" do
        result = described_class.model_details("Vm", :include_id_columns => true)
        expect(result.map(&:second)).to include("Vm-id", "Vm-host_id", "Vm.host-id")
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

  describe ".determine_relat_path (private)" do
    subject { described_class.send(:determine_relat_path, @ref) }

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
      expect(subject).to contain_exactly("=", "!=", "<", "<=", ">=", ">")
    end

    it "returns list of available operations for field type 'float'" do
      @field = "Storage-v_provisioned_percent_of_total"
      expect(subject).to contain_exactly("=", "!=", "<", "<=", ">=", ">")
    end

    #     # there is no example of fields with fixnum datatype available for expression builder
    #     it "returns list of available operations for field type 'fixnum'" do
    #       @field = ?
    #       expect(subject).to eq(["=", "!=", "<", "<=", ">=", ">", "RUBY"])
    #     end

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
    it "return column info for missing model" do
      field = "hostname"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => nil,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => nil,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
      )
    end

    it "return column info for model-virtual field" do
      field = "VmInfra-uncommitted_storage"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :integer,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :bytes,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
      )
    end

    it "return column info for model-virtual field" do
      field = "VmInfra-active"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :boolean,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :boolean,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => true
      )
    end

    it "return column info for model-invalid" do
      field = "ManageIQ::Providers::InfraManager::Vm-invalid"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => nil,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => nil,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
      )
    end

    # TODO: think this should return same results as missing model?
    it "return column info for managed-field (no model)" do
      tag = "managed-location"
      col_info = described_class.get_col_info(tag)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :string,
        :include                        => {},
        :tag                            => true,
        :sql_support                    => false
      )
    end

    it "return column info for model.managed-field" do
      tag = "VmInfra.managed-operations"
      col_info = described_class.get_col_info(tag)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :string,
        :include                        => {},
        :tag                            => true,
        :sql_support                    => true
      )
    end

    it "return column info for model.association.managed-field" do
      tag = "Vm.host.managed-environment"
      col_info = described_class.get_col_info(tag)
      expect(col_info).to match(
        :data_type                      => :string,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :string,
        :include                        => {:host => {}},
        :tag                            => true,
        :sql_support                    => true
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
        :sql_support                    => true
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
        :sql_support                    => true
      )
    end

    it "return column info for model.virtualassociation..virtualassociation-field (with sql)" do
      field = "ManageIQ::Providers::InfraManager::Vm.service.user.vms-uncommitted_storage"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :integer,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :bytes,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
      )
    end

    it "return column info for model.virtualassociation..virtualassociation-invalid" do
      field = "ManageIQ::Providers::InfraManager::Vm.service.user.vms-invalid"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => nil,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => nil,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
      )
    end

    it "return column info for model.invalid-active" do
      field = "ManageIQ::Providers::InfraManager::Vm.invalid-active"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => nil,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => nil,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
      )
    end

    it "return column info for model.virtualassociation..virtualassociation-field (with sql)" do
      field = "ManageIQ::Providers::InfraManager::Vm.service.user.vms-active"
      col_info = described_class.get_col_info(field)
      expect(col_info).to match(
        :data_type                      => :boolean,
        :excluded_by_preprocess_options => false,
        :format_sub_type                => :boolean,
        :include                        => {},
        :tag                            => false,
        :sql_support                    => false
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

        it "returns true for tag of associated model" do
          field = "Vm.ext_management_system.managed-openshiftroles"
          expression = {"CONTAINS" => {"tag" => field, "value" => "node"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(true)
        end

        it "returns false for tag of virtual associated model" do
          field = "Vm.processes.managed-openshiftroles"
          expression = {"CONTAINS" => {"tag" => field, "value" => "node"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end
      end

      context "operation with 'field'" do
        it "returns false if format of field is model.association.association-field" do
          field = "ManageIQ::Providers::InfraManager::Vm.service.user.vms-active"
          expression = {"CONTAINS" => {"field" => field, "value" => "true"}}
          expect(described_class.new(nil).sql_supports_atom?(expression)).to eq(false)
        end

        it "returns false if field belongs to virtual_has_many association" do
          field = "ManageIQ::Providers::InfraManager::Vm.processes-type"
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

    it "supports sql for model.association-virtualfield (with arel)" do
      field = "Host.vms-archived"
      expression = {"=" => {"field" => field, "value" => "true"}}
      expect(described_class.new(expression).sql_supports_atom?(expression)).to eq(true)
    end

    it "does not supports sql for model.association-virtualfield (no arel)" do
      field = "ManageIQ::Providers::InfraManager::Vm.storage-v_used_space"
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
    it "returns true for model.virtualfield (with sql)" do
      field = "ManageIQ::Providers::InfraManager::Vm-archived"
      expression = {"=" => {"field" => field, "value" => "true"}}
      expect(described_class.new(expression).field_in_sql?(field)).to eq(true)
    end

    it "returns false for model.virtualfield (with no sql)" do
      field = "ManageIQ::Providers::InfraManager::Vm-uncommitted_storage"
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

  describe "#evaluate" do
    before do
      @data_hash = {"guest_applications.name"   => "VMware Tools",
                    "guest_applications.vendor" => "VMware, Inc."}
    end

    it "returns true if expression evaluated to value equal to value in supplied hash" do
      expression = {"=" => {"field" => "Vm.guest_applications-name",
                            "value" => "VMware Tools"}}
      obj = described_class.new(expression, "hash")
      expect(obj.evaluate(@data_hash)).to eq(true)
    end

    it "returns false if expression evaluated to value not equal to value in supplied hash" do
      expression = {"=" => {"field" => "Vm.guest_applications-name",
                            "value" => "Hello"}}
      obj = described_class.new(expression, "hash")
      expect(obj.evaluate(@data_hash)).to eq(false)
    end

    it "returns true if expression is regex and there is match in supplied hash" do
      expression = {"REGULAR EXPRESSION MATCHES" => {"field" => "Vm.guest_applications-vendor",
                                                     "value" => "/^[^.]*ware.*$/"}}
      obj = described_class.new(expression, "hash")
      expect(obj.evaluate(@data_hash)).to eq(true)
    end

    it "returns false if expression is regex and there is no match in supplied hash" do
      expression = {"REGULAR EXPRESSION MATCHES" => {"field" => "Vm.guest_applications-vendor",
                                                     "value" => "/^[^.]*hello.*$/"}}
      obj = described_class.new(expression, "hash")
      expect(obj.evaluate(@data_hash)).to eq(false)
    end
  end

  describe ".evaluate_atoms" do
    it "adds mapping 'result'=>false to expression if expression evaluates to false on supplied object" do
      expression = {">=" => {"field" => "Vm-num_cpu",
                             "value" => "2"}}
      result = described_class.evaluate_atoms(expression, FactoryBot.build(:vm))
      expect(result).to include(
        ">="     => {"field" => "Vm-num_cpu",
                     "value" => "2"},
        "result" => false)
    end
  end

  describe ".operands2rubyvalue" do
    RSpec.shared_examples :coerces_value_to_integer do |_value|
      it 'coerces the value to an integer' do
        expect(subject.last).to eq(0)
      end
    end

    let(:operator) { ">" }

    subject do
      described_class.operands2rubyvalue(operator, ops, nil)
    end

    context "when ops field equals count" do
      let(:ops) { {"field" => "<count>", "value" => "foo"} }
      include_examples :coerces_value_to_integer
    end

    context "when ops key is count" do
      let(:ops) do
        {
          "count" => "ManageIQ::Providers::InfraManager::Vm.advanced_settings",
          "value" => "foo"
        }
      end
      include_examples :coerces_value_to_integer
    end
  end

  describe "#fields" do
    it "extracts fields" do
      expression = {
        "AND" => [
          {">=" => {"field" => "EmsClusterPerformance-cpu_usagemhz_rate_average", "value" => "0"}},
          {"<"  => {"field" => "Vm-name", "value" => 5}}
        ]
      }
      actual = described_class.new(expression).fields.sort_by(&:column)
      expect(actual).to contain_exactly(
        an_object_having_attributes(:model => EmsClusterPerformance, :column => "cpu_usagemhz_rate_average"),
        an_object_having_attributes(:model => Vm, :column => "name")
      )
    end

    it "extracts tags" do
      expression = {
        "AND" => [
          {">=" => {"field" => "EmsClusterPerformance-cpu_usagemhz_rate_average", "value" => "0"}},
          {"<"  => {"field" => "Vm.managed-favorite_color", "value" => "5"}}
        ]
      }
      actual = described_class.new(expression).fields
      expect(actual).to contain_exactly(
        an_object_having_attributes(:model => EmsClusterPerformance, :column => "cpu_usagemhz_rate_average"),
        an_object_having_attributes(:model => Vm, :namespace => "/managed/favorite_color")
      )
    end

    it "extracts values" do
      expression =
        {">=" => {"field" => "EmsClusterPerformance-cpu_usagemhz_rate_average", "value" => "Vm.managed-favorite_color"}}
      actual = described_class.new(expression).fields
      expect(actual).to contain_exactly(
        an_object_having_attributes(:model => EmsClusterPerformance, :column => "cpu_usagemhz_rate_average"),
        an_object_having_attributes(:model => Vm, :namespace => "/managed/favorite_color")
      )
    end
  end

  describe "#set_tagged_target" do
    it "will substitute a new class into the expression" do
      expression = described_class.new("CONTAINS" => {"tag" => "managed-environment", "value" => "prod"})

      expression.set_tagged_target(Vm)

      expect(expression.exp).to eq("CONTAINS" => {"tag" => "Vm.managed-environment", "value" => "prod"})
    end

    it "will substitute a new class and associations into the expression" do
      expression = described_class.new("CONTAINS" => {"tag" => "managed-environment", "value" => "prod"})

      expression.set_tagged_target(Vm, ["host"])

      expect(expression.exp).to eq("CONTAINS" => {"tag" => "Vm.host.managed-environment", "value" => "prod"})
    end

    it "can handle OR expressions" do
      expression = described_class.new(
        "OR" => [
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "managed-location", "value" => "ny"}}
        ]
      )

      expression.set_tagged_target(Vm)

      expected = {
        "OR" => [
          {"CONTAINS" => {"tag" => "Vm.managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "Vm.managed-location", "value" => "ny"}}
        ]
      }
      expect(expression.exp).to eq(expected)
    end

    it "can handle AND expressions" do
      expression = described_class.new(
        "AND" => [
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "managed-location", "value" => "ny"}}
        ]
      )

      expression.set_tagged_target(Vm)

      expected = {
        "AND" => [
          {"CONTAINS" => {"tag" => "Vm.managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "Vm.managed-location", "value" => "ny"}}
        ]
      }
      expect(expression.exp).to eq(expected)
    end

    it "can handle NOT expressions" do
      expression = described_class.new("NOT" => {"CONTAINS" => {"tag" => "managed-environment", "value" => "prod"}})

      expression.set_tagged_target(Vm)

      expected = {"NOT" => {"CONTAINS" => {"tag" => "Vm.managed-environment", "value" => "prod"}}}
      expect(expression.exp).to eq(expected)
    end

    it "will not change the target of fields" do
      expression = described_class.new("=" => {"field" => "Vm-vendor", "value" => "redhat"})

      expression.set_tagged_target(Host)

      expect(expression.exp).to eq("=" => {"field" => "Vm-vendor", "value" => "redhat"})
    end

    it "will not change the target of counts" do
      expression = described_class.new("=" => {"count" => "Vm.disks", "value" => "1"})

      expression.set_tagged_target(Host)

      expect(expression.exp).to eq("=" => {"count" => "Vm.disks", "value" => "1"})
    end
  end

  describe ".tag_details" do
    before do
      described_class.instance_variable_set(:@classifications, nil)
    end

    it "returns the tags when no path is given" do
      Tenant.seed
      FactoryBot.create(
        :classification,
        :name        => "env",
        :description => "Environment",
        :children    => [FactoryBot.create(:classification)]
      )
      actual = described_class.tag_details(nil, {})
      expect(actual).to eq([["My Company Tags : Environment", "managed-env"]])
    end

    it "returns the added classification when no_cache option is used" do
      Tenant.seed
      FactoryBot.create(:classification,
                         :name        => "first_classification",
                         :description => "First Classification",
                         :children    => [FactoryBot.create(:classification)])
      actual = described_class.tag_details(nil, {})
      expect(actual).to eq([["My Company Tags : First Classification", "managed-first_classification"]])

      FactoryBot.create(:classification,
                         :name        => "second_classification",
                         :description => "Second Classification",
                         :children    => [FactoryBot.create(:classification)])
      actual = described_class.tag_details(nil, :no_cache => true)
      expect(actual).to eq([["My Company Tags : First Classification", "managed-first_classification"], ["My Company Tags : Second Classification", "managed-second_classification"]])
    end
  end

  describe "miq_adv_search_lists" do
    it ":exp_available_counts" do
      result = described_class.miq_adv_search_lists(Vm, :exp_available_counts)

      expect(result.map(&:first)).to include(" VM and Instance.Users")
    end

    it ":exp_available_finds" do
      result = described_class.miq_adv_search_lists(Vm, :exp_available_finds)

      expect(result.map(&:first)).to include("VM and Instance.Provisioned VMs : Href Slug")
      expect(result.map(&:first)).not_to include("VM and Instance : Id")
    end

    it ":exp_available_fields with include_id_columns" do
      result = described_class.miq_adv_search_lists(Vm, :exp_available_fields, :include_id_columns => true)
      expect(result.map(&:first)).to include("VM and Instance : Id")
    end
  end

  describe ".quote" do
    [
      ["abc", :string, "\"abc\""],
      ["abc", nil, "\"abc\""],
      ["123", :integer, 123],
      ["1.minute", :integer, 60],
    ].each do |src, type, target|
      it "escapes #{src} as a #{type || "nil"}" do
        expect(described_class.quote(src, type)).to eq(target)
      end
    end
  end

  describe ".quote_human" do
    [
      ["abc", :string, "\"abc\""],
      ["abc", nil, "\"abc\""],
      ["123", :integer, 123],
      ["1.minute", :integer, "1 Minute"],
    ].each do |src, type, target|
      it "escapes #{src} as a #{type || "nil"}" do
        expect(described_class.quote_human(src, type)).to eq(target)
      end
    end
  end

  private

  def sql_pruned_exp(input)
    mexp = MiqExpression.new(input)
    pexp = mexp.preprocess_exp!(mexp.exp.deep_clone)
    mexp.prune_exp(pexp, MiqExpression::MODE_SQL).first
  end

  def ruby_pruned_exp(input)
    mexp = MiqExpression.new(input)
    pexp = mexp.preprocess_exp!(mexp.exp.deep_clone)
    mexp.prune_exp(pexp, MiqExpression::MODE_RUBY).first
  end
end
