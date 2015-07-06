require "spec_helper"
require Rails.root.join("db/migrate/20140121213913_split_widget_set_name_to_three_columns.rb")

describe SplitWidgetSetNameToThreeColumns do
  migration_context :up do
    let(:miq_set_stub) { migration_stub(:MiqSet) }

    it "splits name value into 3 columns: name, userid and group_id" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "admin|123|my board")

      migrate

      ws = miq_set_stub.first
      expect(ws.name).to    eq("my board")
      expect(ws.userid).to  eq("admin")
      expect(ws.group_id).to eq(123)
    end

    it "deletes the record with name like userid|db_name" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "admin|my board")

      migrate

      expect(miq_set_stub.count).to eq(0)
    end

    it "keeps the record with name like db_name" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "my board")

      migrate

      ws = miq_set_stub.first
      expect(ws.name).to     eq("my board")
      expect(ws.userid).to   be_nil
      expect(ws.group_id).to be_nil
    end

    it "deletes the record with name like userid|group_id|db_name|whatever" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "admin|123|my board|whatever")

      migrate

      expect(miq_set_stub.count).to eq(0)
    end
  end

  migration_context :down do
    let(:miq_set_stub) { migration_stub(:MiqSet) }

    it "puts userid, group_id into name value" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "my board", :userid => "test", :group_id => 99)

      migrate

      ws = miq_set_stub.first
      expect(ws.name).to eq("test|99|my board")
      expect { ws.userid }.to  raise_error(NoMethodError)
      expect { ws.group_id }.to raise_error(NoMethodError)
    end

    it "leaves the record as is when group_id = nil" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "my board", :userid => "test")

      migrate

      ws = miq_set_stub.first
      expect(ws.name).to eq("my board")
      expect { ws.userid }.to  raise_error(NoMethodError)
      expect { ws.group_id }.to raise_error(NoMethodError)
    end

    it "leaves the record as is when userid = nil" do
      miq_set_stub.create!(:set_type => 'MiqWidgetSet', :name => "my board", :group_id => 123)

      migrate

      ws = miq_set_stub.first
      expect(ws.name).to eq("my board")
      expect { ws.userid }.to  raise_error(NoMethodError)
      expect { ws.group_id }.to raise_error(NoMethodError)
    end
  end
end
