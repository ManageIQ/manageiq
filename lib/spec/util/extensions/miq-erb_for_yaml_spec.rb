require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-erb_for_yaml'

describe MiqERBForYAML do
  context "yaml load after ERB#result" do
    it "leading YAML characters" do
      erb = MiqERBForYAML.new("--- \nname: <%= \"!#Joe\" %>")
      YAML.load(erb.result).should == {'name' => '!#Joe'}
    end

    it "leading %" do
      erb = MiqERBForYAML.new("--- \nname: <%= \"\%Joe\" %>")
      YAML.load(erb.result).should == {'name' => "%Joe" }
    end

    it "backslash within" do
      erb = MiqERBForYAML.new("--- \nname: <%= 'Joe\\234' %>")
      YAML.load(erb.result).should == {'name' => 'Joe\234'}
    end

    it "single quote within" do
      erb = MiqERBForYAML.new("--- \nname: <%= \"Joe\'234\" %>")
      YAML.load(erb.result).should == {'name' => "Joe\'234"}
    end

    it "double quote within" do
      erb = MiqERBForYAML.new("--- \nname: <%= 'Joe\"234' %>")
      YAML.load(erb.result).should == {'name' => "Joe\"234"}
    end
  end

end
