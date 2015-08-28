require "spec_helper"
require File.expand_path("../app/controllers/application_controller/", "feature.rb")

describe ApplicationController do
  context "Feature" do
    Feature = ApplicationController.const_get('Feature')

    it "#new_with_hash creates a Struct" do
      Feature.new_with_hash(:name => "whatever").should be_a_kind_of(Struct)
    end

    it "#autocomplete doesn't replace stuff" do
      feature = Feature.new_with_hash(:name => "foo", :accord_name => "bar", :tree_name => "quux", :container => "frob")
      feature.accord_name.should eq("bar")
      feature.tree_name.should eq("quux")
      feature.container.should eq("frob")
    end

    it "#autocomplete does set missing stuff" do
      feature = Feature.new_with_hash(:name => "foo")
      feature.accord_name.should eq("foo")
      feature.tree_name.should eq(:foo_tree)
      feature.container.should eq("foo_tree_div")
    end
  end
end
