require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. VMwareWebService})))
require 'VimMappingRegistry'

describe VimMappingRegistry do
  VMR_ABOUT_INFO = {
    "dynamicType"           => {:type => :"SOAP::SOAPString"},
    "dynamicProperty"       => {:type => :DynamicProperty, :isArray => true},
    "name"                  => {:type => :"SOAP::SOAPString"},
    "fullName"              => {:type => :"SOAP::SOAPString"},
    "vendor"                => {:type => :"SOAP::SOAPString"},
    "version"               => {:type => :"SOAP::SOAPString"},
    "build"                 => {:type => :"SOAP::SOAPString"},
    "localeVersion"         => {:type => :"SOAP::SOAPString"},
    "localeBuild"           => {:type => :"SOAP::SOAPString"},
    "osType"                => {:type => :"SOAP::SOAPString"},
    "productLineId"         => {:type => :"SOAP::SOAPString"},
    "apiType"               => {:type => :"SOAP::SOAPString"},
    "apiVersion"            => {:type => :"SOAP::SOAPString"},
    "instanceUuid"          => {:type => :"SOAP::SOAPString"},
    "licenseProductName"    => {:type => :"SOAP::SOAPString"},
    "licenseProductVersion" => {:type => :"SOAP::SOAPString"}
  }

  context ".registry" do
    it "handles all known methods" do
      known_methods = Dir.glob(File.join(VimMappingRegistry::YML_DIR, "*.yml")).collect {|p| File.basename(p, ".yml")}

      known_methods.each do |m|
        expect(described_class.registry[m]).to be_kind_of Hash
      end
    end

    it "handles unknown methods" do
      expect(described_class.registry["XXX"]).to be_nil
    end

    it "with a specific method" do
      expect(described_class.registry["AboutInfo"]).to eq VMR_ABOUT_INFO
    end
  end

  it ".argInfoMap" do
    expect(described_class.argInfoMap("AboutInfo")).to eq VMR_ABOUT_INFO
  end

  it ".args" do
    expect(described_class.args("AboutInfo")).to match_array VMR_ABOUT_INFO.keys
  end
end
