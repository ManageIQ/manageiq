class VimPerformanceOperatingRange < ApplicationRecord
  belongs_to  :resource, :polymorphic => true
  belongs_to  :time_profile

  serialize   :values

  DEFAULT_STD_DEV_MULT = 1
  SUB_YAML_REGEX_PARTIAL=("[^\\n]*\\n" * 5).freeze

  def values_to_metrics(options = {})
    options[:std_dev_mult] ||= DEFAULT_STD_DEV_MULT

    results = values.dup.merge(:low => {}, :high => {})
    results[:avg].each_key do |c|
      dev = (results[:dev][c] * options[:std_dev_mult])
      results[:low][c]  = results[:avg][c] - dev
      results[:low][c]  = 0 if results[:low][c] < 0
      results[:high][c] = results[:avg][c] + dev
    end

    metrics = {}
    Metric::LongTermAverages::AVG_METHODS_INFO.each do |meth, info|
      metrics[meth.to_s] = results.fetch_path(info[:type], info[:column])
    end

    metrics
  end

  def self.virtual_attribute_avg_for_col(col)
    lambda { |t| avg_value_arel(col) }
  end

  def self.virtual_attribute_low_for_col(col)
    lambda do |t|
      zero      = Arel::Nodes::SqlLiteral.new('0')
      low_value = Arel::Nodes::Subtraction.new avg_value_arel(col), dev_value_arel(col)
      t.grouping(Arel::Nodes::NamedFunction.new("GREATEST", [ low_value, zero ]))
    end
  end

  def self.virtual_attribute_high_for_col(col)
    lambda do |t|
      t.grouping(Arel::Nodes::Addition.new avg_value_arel(col), dev_value_arel(col))
    end
  end

  Metric::LongTermAverages::AVG_METHODS_INFO.each do |meth, info|
    virtual_attribute meth, :float,
      :arel => send("virtual_attribute_#{info[:type]}_for_col", info[:column])

    define_method(meth) do
      if has_attribute?(meth.to_s)
        self[meth.to_s]
      elsif has_attribute?("values")
        values_to_metrics[meth]
      else
        0
      end
    end
  end

  def self.avg_value_arel(col)
    sub_yaml_col_select("avg", col)
  end

  def self.dev_value_arel(col)
    sub_yaml_col_select("dev", col)
  end

  def self.sub_yaml_col_select(section, col)
    avg_yaml_match = Arel::Nodes::SqlLiteral.new(%Q{#{arel_table_col_as_string(:values)} from '#{section}:#{SUB_YAML_REGEX_PARTIAL}'})
    inner_substring = Arel::Nodes::NamedFunction.new("substring", [avg_yaml_match])

    number_match    = Arel::Nodes::SqlLiteral.new("#{inner_substring.to_sql} from '#{col}: ([0-9\.]+)'")
    outer_substring = Arel::Nodes::NamedFunction.new("substring", [number_match])
    Arel::Nodes::NamedFunction.new("CAST", [outer_substring.as("double precision")])
  end

  def self.arel_table_col_as_string(col)
    visitor = Arel::Visitors::ToSql.new(connection)
    visitor.accept(arel_table[col], Arel::Collectors::SQLString.new).value
  end
  private_class_method :arel_table_col_as_string
end
