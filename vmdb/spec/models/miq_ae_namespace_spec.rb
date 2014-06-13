require "spec_helper"

describe MiqAeNamespace do

  it { should belong_to(:parent)        }
  it { should have_many(:ae_namespaces) }
  it { should have_many(:ae_classes)    }

  it { should validate_presence_of(:name) }

  it { should allow_value("name.space1").for(:name) }
  it { should allow_value("name-space1").for(:name) }
  it { should allow_value("name$space1").for(:name) }

  it { should_not allow_value("name space1").for(:name) }
  it { should_not allow_value("name:space1").for(:name) }

  it "should find or create namespaces by fqname" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("System/TEST")
    n1.should_not be_nil
    n1.save!.should be_true

    n2 = MiqAeNamespace.find_by_fqname("SYSTEM/test")
    n2.should_not be_nil
    n2.should == n1

    n2 = MiqAeNamespace.find_by_fqname("system")
    n2.should_not be_nil
    n2.should == n1.parent

    MiqAeNamespace.find_by_fqname("TEST").should be_nil
  end

  it "should set the updated_by field on save" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("foo/bar")
    n1.updated_by.should == 'system'

    n2 = MiqAeNamespace.find_by_fqname("foo")
    n2.updated_by.should == 'system'
  end

  it "should have system property as false by default" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("ns1/ns2")
    n1.system.should be_false
    n2 = MiqAeNamespace.find_or_create_by_fqname("ns1")
    n2.system.should be_false
  end

  it "should return editable as false if the parent has the system property set to true" do
    n1 = MiqAeNamespace.create!(:name => 'ns1', :priority => 10, :system => true)
    n1.should_not be_editable

    n2 = MiqAeNamespace.create!(:name => 'ns2', :parent_id => n1.id)

    n3 = MiqAeNamespace.create!(:name => 'ns3', :parent_id => n2.id)
    n3.should_not be_editable
  end

  it "should return editable as true if the namespace doesn't have the system property defined" do
    n1 = MiqAeNamespace.create!(:name => 'ns1')
    n1.should be_editable
  end

end
