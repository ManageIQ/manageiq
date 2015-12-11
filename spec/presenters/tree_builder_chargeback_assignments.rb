require 'spec_helper'

describe TreeBuilderChargebackAssignments do
  context "#x_get_tree_roots" do
    it "correctly renders storage and compute nodes when no rates are available" do
      tree = TreeBuilderChargebackAssignments.new("cb_rates_tree", "cb_rates", {})
      keys = JSON.parse(tree.tree_nodes).first['children'].collect { |x| x['key'] }
      titles = JSON.parse(tree.tree_nodes).first['children'].collect { |x| x['title'] }
      rates = ChargebackRate.all

      expect(rates).to be_empty
      expect(keys).to match_array %w(xx-Compute xx-Storage)
      expect(titles).to match_array %w(Compute Storage)
    end
  end
end
