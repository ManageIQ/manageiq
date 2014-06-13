require "spec_helper"
include UiConstants

describe ApplicationController do

  context "audit events" do

    it "tests build_config_audit" do
      edit = {:current => {:changing_value=>"test",  :static_value=>"same", :password=>"pw1"},
              :new     => {:changing_value=>"test2", :static_value=>"same", :password=>"pw2"}}
      controller.send(:build_config_audit,edit[:new], edit[:current]).
        should == {:event   => "vmdb_config_update",
                   :userid  => nil,
                   :message => "VMDB config updated (changing_value:[test] to [test2], password:[*] to [*])"}
    end

    it "tests build_created_audit" do
      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      edit = {:new     => {:name => "the-name", :changing_value=>"test2", :static_value=>"same",
                           :hash_value=>{:h1=>"first",:h2=>"second", :hash_password=>"pw1"},
                           :password=>"pw1"}}
      controller.send(:build_created_audit, category, edit).
        should == {:event        => "classification_record_add",
                   :target_id    => category.id,
                   :target_class => category.class.name,
                   :userid       => nil,
                   :message      => "[the-name] Record created (name:[the-name], changing_value:[test2], static_value:[same], h1:[first], h2:[second], hash_password:[*], password:[*])"}
    end

    it "tests build_saved_audit" do
      category = FactoryGirl.create(:classification, :name => 'environment', :description => 'Environment')
      edit = {:current => {:name => "the-name", :changing_value=>"test",  :static_value=>"same",
                           :hash_value=>{:h1=>"first",:h2=>"second", :hash_password=>"pw1"}},
              :new     => {:name => "the-name", :changing_value=>"test2", :static_value=>"same",
                           :hash_value=>{:h1=>"firsts",:h2=>"seconds", :hash_password=>"pw2"}}}
      controller.send(:build_saved_audit, category, edit).
        should == {:event        => "classification_record_update",
                   :target_id    => category.id,
                   :target_class => category.class.name,
                   :userid       => nil,
                   :message      => "[the-name] Record updated (changing_value:[test] to [test2], h1:[first] to [firsts], h2:[second] to [seconds], hash_password:[*] to [*])"}
    end
  end
end
