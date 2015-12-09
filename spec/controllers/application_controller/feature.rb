require "spec_helper"
require File.expand_path("../app/controllers/application_controller/", "feature.rb")

describe ApplicationController do
  context "Feature" do
    Feature = ApplicationController.const_get('Feature')

    it "#new_with_hash creates a Struct" do
      expect(Feature.new_with_hash(:name => "whatever")).to be_a_kind_of(Struct)
    end

    it "#autocomplete doesn't replace stuff" do
      feature = Feature.new_with_hash(:name => "foo", :accord_name => "bar", :tree_name => "quux", :container => "frob")
      expect(feature.accord_name).to eq("bar")
      expect(feature.tree_name).to eq("quux")
      expect(feature.container).to eq("frob")
    end

    it "#autocomplete does set missing stuff" do
      feature = Feature.new_with_hash(:name => "foo")
      expect(feature.accord_name).to eq("foo")
      expect(feature.tree_name).to eq(:foo_tree)
      expect(feature.container).to eq("foo_tree_div")
    end
  end
end
