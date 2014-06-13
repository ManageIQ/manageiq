require "spec_helper"

describe TreeBuilder do
  context "initialize" do
    it "initializes a tree" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      tree.should be_a_kind_of(TreeBuilder)
      tree.name.should == :cb_rates_tree
    end

    it "sets sandbox hash that can be accessed by other methods in the class" do
      sb = {}
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", sb)
      tree.should be_a_kind_of(TreeBuilder)
      tree.name.should == :cb_rates_tree
      sb.has_key?(:trees)
      sb[:trees].has_key?(:cb_rates_tree)
    end
  end

  context "title_and_tip" do
    it "sets title and tooltip for the passed in root node" do
      title, tooltip, icon = TreeBuilder.root_options(:cb_rates_tree)
      title.should    == "Rates"
      tooltip.should  == "Rates"
      icon.should be_nil
    end
  end

  context "build_tree" do
    it "builds tree object and sets all settings and add nodes to tree object" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      nodes = [{:key      => "root",
                :children => [],
                :expand   => true,
                :title    => "Rates",
                :tooltip  => "Rates",
                :icon     => "folder.png"
              }]
      tree.locals_for_render.has_key?(:json_tree)
      tree.locals_for_render[:json_tree].should == nodes.to_json
    end
  end

end
