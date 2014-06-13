require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. RedHatEnterpriseVirtualizationManagerAPI})))
require 'rhevm_api'

describe RhevmObject do
  it ".api_endpoint" do
    described_class.api_endpoint.should == "objects"
    RhevmTemplate.api_endpoint.should == "templates"
    RhevmCluster.api_endpoint.should == "clusters"
    RhevmVm.api_endpoint.should == "vms"
    RhevmStorageDomain.api_endpoint.should == "storagedomains"
    RhevmDataCenter.api_endpoint.should == "datacenters"
  end
end
