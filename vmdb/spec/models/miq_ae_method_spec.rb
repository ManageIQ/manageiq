require "spec_helper"

describe MiqAeMethod do
  it "should return editable as false if the parent namespace/class is not editable" do
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10, :system => true)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    f1.should_not be_editable
  end

  it "should return editable as true if the parent namespace/class is editable" do
    n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1')
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    f1 = FactoryGirl.create(:miq_ae_method,
                            :class_id => c1.id,
                            :name     => "foo_method",
                            :scope    => "instance",
                            :language => "ruby",
                            :location => "inline")
    f1.should be_editable
  end
end
