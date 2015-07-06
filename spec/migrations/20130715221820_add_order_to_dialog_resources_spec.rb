# encoding: utf-8

require "spec_helper"
require Rails.root.join("db/migrate/20130715221820_add_order_to_dialog_resources.rb")

describe AddOrderToDialogResources do
  migration_context :up do
    let(:dialog_resource_stub) { migration_stub(:DialogResource) }
    let(:dialog_stub)          { migration_stub(:Dialog) }
    let(:dialog_tab_stub)      { migration_stub(:DialogTab) }
    let(:dialog_group_stub)    { migration_stub(:DialogGroup) }
    let(:dialog_field_stub)    { migration_stub(:DialogField) }

    it "move dialog_tab relationship from join-table to instance" do
      dlg     = dialog_stub.create!(:label => "parent")
      dlg_tab = dialog_tab_stub.create!(:label => "child")
      dlg_rsc = dialog_resource_stub.create!(:parent_id => dlg.id,       :parent_type   => "Dialog",
                                             :resource_id => dlg_tab.id, :resource_type => "DialogTab",
                                             :order => 0)

      migrate

      dlg_tab.reload
      dlg_tab.order.should == 0
      dlg_tab.dialog_id.should == dlg.id
    end

    it "move dialog_group relationship from join-table to instance" do
      dlg_tab   = dialog_tab_stub.create!(:label => "parent")
      dlg_group = dialog_group_stub.create!(:label => "child")
      dlg_rsc   = dialog_resource_stub.create!(:parent_id   => dlg_tab.id,   :parent_type   => "DialogTab",
                                               :resource_id => dlg_group.id, :resource_type => "DialogGroup",
                                               :order => 1)

      migrate

      dlg_group.reload
      dlg_group.order.should == 1
      dlg_group.dialog_tab_id.should == dlg_tab.id
    end

    it "move dialog_field relationship from join-table to instance" do
      dlg_group = dialog_group_stub.create!(:label => "parent")
      dlg_field = dialog_field_stub.create!(:label => "child", :name =>"child")
      dlg_rsc   = dialog_resource_stub.create!(:parent_id   => dlg_group.id, :parent_type   => "DialogGroup",
                                               :resource_id => dlg_field.id, :resource_type => "DialogField",
                                               :order => 2)
      migrate

      dlg_field.reload
      dlg_field.order.should == 2
      dlg_field.dialog_group_id.should == dlg_group.id
    end
  end

  migration_context :down do
    let(:dialog_resource_stub) { migration_stub(:DialogResource) }
    let(:dialog_stub)          { migration_stub(:Dialog) }
    let(:dialog_tab_stub)      { migration_stub(:DialogTab) }
    let(:dialog_group_stub)    { migration_stub(:DialogGroup) }
    let(:dialog_field_stub)    { migration_stub(:DialogField) }

    it "move dialog_tab relationship from instance to join-table" do
      dlg     = dialog_stub.create!(:label => "parent")
      dlg_tab = dialog_tab_stub.create!(:label => "child", :dialog_id => dlg.id, :order => 0)

      migrate

      dr = dialog_resource_stub.first
      dr.parent_type.should   == "Dialog"
      dr.parent_id.should     == dlg.id
      dr.resource_type.should == "DialogTab"
      dr.resource_id.should   == dlg_tab.id
      dr.order.should         == 0
    end

    it "move dialog_group relationship from instance to join-table" do
      dlg_tab   = dialog_tab_stub.create!(:label => "parent")
      dlg_group = dialog_group_stub.create!(:label => "child", :dialog_tab_id => dlg_tab.id, :order => 1)

      migrate

      dr = dialog_resource_stub.first
      dr.parent_type.should   == "DialogTab"
      dr.parent_id.should     == dlg_tab.id
      dr.resource_type.should == "DialogGroup"
      dr.resource_id.should   == dlg_group.id
      dr.order.should         == 1
    end

    it "move dialog_field relationship from instance to join-table" do
      dlg_group = dialog_group_stub.create!(:label => "parent")
      dlg_field = dialog_field_stub.create!(:label => "child", :name => "child", :dialog_group_id => dlg_group.id, :order => 2)

      migrate

      dr = dialog_resource_stub.first
      dr.parent_type.should   == "DialogGroup"
      dr.parent_id.should     == dlg_group.id
      dr.resource_type.should == "DialogField"
      dr.resource_id.should   == dlg_field.id
      dr.order.should         == 2
    end
  end
end
