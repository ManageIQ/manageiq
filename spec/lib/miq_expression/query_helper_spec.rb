RSpec.describe MiqExpression::QueryHelper do
  describe ".remove_node" do
    let(:vm_host_id) { Vm.arel_table[:host_id] }
    let(:host_id) { Host.arel_table[:id] }
    let(:host_type) { Host.arel_table[:type] }
    let(:bind_param) do
      if ActiveRecord.version.to_s >= "5.2"
        Arel::Nodes::BindParam.new(host_type)
      else
        Arel::Nodes::BindParam.new
      end
    end
    let(:matching_query) { vm_host_id.eq(host_id) }

    # query:  nil
    # result: nil
    it "handles an empty query" do
      query = nil
      result = described_class.remove_node(query, matching_query)
      expect(result).to be_nil
    end

    # query:  "vms"."host_id" = "hosts"."id"
    # result: nil
    it "removes a matching query" do
      query = matching_query
      result = described_class.remove_node(query, matching_query)
      expect(result).to be_nil
    end

    # query:  "hosts"."id" = "vms"."host_id"
    # result: nil
    it "removes a matching query (opposite order)" do
      query = host_id.eq(vm_host_id)
      result = described_class.remove_node(query, matching_query)
      expect(result).to be_nil
    end

    # query:  "hosts"."type" = 'abc'
    # result: "hosts"."type" = 'abc'
    it "keeps a query that does not have `matching_query` in it" do
      query = host_type.eq('abc')
      result = described_class.remove_node(query, matching_query, [])
      expect(result).to eq(query)
    end

    # query:  "hosts"."type" = ?
    # result: "hosts"."type" = 5
    it "keeps a query that does not have `matching_query` in it, replacing the binds" do
      query = host_type.eq(bind_param)
      expected = host_type.eq(Arel::Nodes::Casted.new(5, host_type))
      result = described_class.remove_node(query, matching_query, bind_values(5))
      expect(result).to eq(expected)
    end

    # query:  "hosts"."type" = 'abc'
    # result: "hosts"."type" = 'abc'
    # A single element in an and doesn't make sense, but we saw it come into this method so we test it
    it "removes a matching query in an AND (single node)" do
      query = arel_and(matching_query)
      result = described_class.remove_node(query, matching_query)
      expect(result).to be_nil
    end

    # query: "hosts"."id" = "vms"."host_id"
    # result: nil
    # The input form is not quite valid, but we saw it come into this method so we test it
    it "removes matching and nil nodes in an AND" do
      query = arel_and(nil, matching_query)
      result = described_class.remove_node(query, matching_query)
      expect(result).to be_nil
    end

    # query:  "vms"."host_id" = "hosts"."id" AND "hosts"."type" = 'abc' AND "hosts"."type" = 'def'
    # result: "hosts"."type" = 'abc' AND "hosts"."type" = 'abc'
    it "removes matching query at the beginning of a tripple AND" do
      query = arel_and(matching_query, host_type.eq('abc'), host_type.eq('def'))
      expected = host_type.eq('abc').and(host_type.eq('def'))
      result = described_class.remove_node(query, matching_query)
      expect(result).to eq(expected)
    end

    # query:  "hosts"."type" = 'abc' AND "vms"."host_id" = "hosts"."id" AND "hosts"."type" = 'def'
    # result: "hosts"."type" = 'abc' AND "hosts"."type" = 'def'
    it "removes matching query in the middle of a tripple AND" do
      query = arel_and(host_type.eq('abc'), matching_query, host_type.eq('def'))
      expected = host_type.eq('abc').and(host_type.eq('def'))
      result = described_class.remove_node(query, matching_query, [])
      expect(result).to eq(expected)
    end

    # query:  "vms"."host_id" = "hosts"."id" AND "hosts"."type" = 'abc' AND "hosts"."type" = 'def'
    # result: "hosts"."type" = 'abc' AND "hosts"."type" = 'def'
    it "removes matching query at the end of a tripple AND" do
      query = matching_query.and(host_type.eq('abc').and(host_type.eq('def')))
      expected = host_type.eq('abc').and(host_type.eq('def'))
      result = described_class.remove_node(query, matching_query)
      expect(result).to eq(expected)
    end

    # query:  "hosts"."type" = 'abc' AND "vms"."host_id" = "hosts"."id" AND "hosts"."type" = 'def'
    # result: "hosts"."type" = 'abc' AND "hosts"."type" = 'abc'
    it "removes matching query from multiple layers where our equality is at the base" do
      query = host_type.eq('abc').and(matching_query.and(host_type.eq('def')))
      expected = host_type.eq('abc').and(host_type.eq('def'))
      result = described_class.remove_node(query, matching_query)
      expect(result).to eq(expected)
    end

    # query:  ("hosts"."type" = 'abc') AND "vms"."host_id" = "hosts"."id"
    # result: ("hosts"."type" = 'abc')
    it "removes matching query with grouped other node" do
      query = arel_group(host_type.eq('abc')).and(matching_query)
      result = described_class.remove_node(query, matching_query, [])
      expect(result).to eq(arel_group(host_type.eq('abc')))
    end

    # query:  "hosts"."type" = 'abc' AND ("vms"."host_id" = "hosts"."id")
    # result: "hosts"."type" = 'abc'
    it "removes matching node with grouped matchng node" do
      query = host_type.eq('abc').and(arel_group(matching_query))
      result = described_class.remove_node(query, matching_query)
      expect(result).to eq(host_type.eq('abc'))
    end

    private

    def bind_values(*values)
      values.map do |value|
        type = value.kind_of?(String) ? ActiveModel::Type::String.new : ActiveModel::Type::Integer.new
        if ActiveRecord.version.to_s >= "5.2"
          ActiveModel::Attribute.from_database('param', value, type)
        else
          ActiveRecord::Attribute.from_database('param', value, type)
        end
      end
    end

    # this helps us create some of the odd use cases we've seen come into this method
    def arel_and(*nodes)
      Arel::Nodes::And.new(nodes)
    end

    # add parens around one or more nodes
    def arel_group(node)
      Arel::Nodes::Grouping.new(node)
    end
  end
end
