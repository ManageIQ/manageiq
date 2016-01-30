require 'util/extensions/miq-erb_for_yaml'

describe MiqERBForYAML do
  context "yaml load after ERB#result" do
    it "leading YAML characters" do
      erb = MiqERBForYAML.new("--- \nname: <%= \"!#Joe\" %>")
      expect(YAML.load(erb.result)).to eq({'name' => '!#Joe'})
    end

    it "leading %" do
      erb = MiqERBForYAML.new("--- \nname: <%= \"\%Joe\" %>")
      expect(YAML.load(erb.result)).to eq({'name' => "%Joe"})
    end

    it "backslash within" do
      erb = MiqERBForYAML.new("--- \nname: <%= 'Joe\\234' %>")
      expect(YAML.load(erb.result)).to eq({'name' => 'Joe\234'})
    end

    it "single quote within" do
      erb = MiqERBForYAML.new("--- \nname: <%= \"Joe\'234\" %>")
      expect(YAML.load(erb.result)).to eq({'name' => "Joe\'234"})
    end

    it "double quote within" do
      erb = MiqERBForYAML.new("--- \nname: <%= 'Joe\"234' %>")
      expect(YAML.load(erb.result)).to eq({'name' => "Joe\"234"})
    end
  end
end
