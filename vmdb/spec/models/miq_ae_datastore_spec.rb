require "spec_helper"

describe MiqAeDatastore do

  it ".backup" do
    MiqAeYamlExportZipfs.any_instance.should_receive(:export).once
    MiqAeDatastore.backup('zip_file'  => 'dummy', 'overwrite' => true)
  end

  it ".restore" do
    dummy_zipfile = File.expand_path(File.join(File.dirname(__FILE__), "/miq_ae_datastore/data/dummy.zip"))
    MiqAeYamlImport.any_instance.should_receive(:import).once

    MiqAeDatastore.restore(dummy_zipfile)
  end

  it ".upload" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    MiqAeDatastore.should_receive(:import_yaml_zip).with(import_file, "*").once

    MiqAeDatastore.upload(fd, "dummy.zip")
  end

  it ".reset_default_namespace" do
    MiqAeDatastore.reset_default_namespace

    MiqAeNamespace.first.name.should eq("$")
    MiqAeClass.first.name.should     eq("Object")
    MiqAeMethod.count.should         eq(3)
  end

  it "temporary file cleanup for unsuccessful import" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    expect { MiqAeDatastore.upload(fd, "dummy.zip") }.to raise_error
    File.exist?(import_file).should be_false
  end

  it "temporary file cleanup for successful import" do
    fd = double(:original_filename => "dummy.zip", :read => "junk", :eof => true, :close => true)
    import_file = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine", "dummy.zip"))
    MiqAeDatastore.should_receive(:import_yaml_zip).with(import_file, "*").once
    MiqAeDatastore.upload(fd, "dummy.zip")
    File.exist?(import_file).should be_false
  end

end
