require "spec_helper"

describe ReservedMixin do
  before(:each) do
    class TestClass < ActiveRecord::Base
      self.table_name = "vms"
      include ReservedMixin
      attr_via_reserved :some_field
    end
  end

  after(:each) do
    Object.send(:remove_const, :TestClass)
  end

  context ".attr_via_reserved" do
    it "normal case" do
      t = TestClass.new
      t.should respond_to(:some_field)
      t.should respond_to(:some_field?)
      t.should respond_to(:some_field=)

      t.some_field = "test"
      t.some_field.should  == "test"
      t.some_field?.should be_true

      t.some_field = nil
      t.some_field.should  be_nil
      t.some_field?.should be_false
    end

    it "with multiple fields" do
      class TestClass
        attr_via_reserved :another_field, :a_third_field
      end

      t = TestClass.new
      t.should respond_to(:another_field)
      t.should respond_to(:another_field?)
      t.should respond_to(:another_field=)
      t.should respond_to(:a_third_field)
      t.should respond_to(:a_third_field?)
      t.should respond_to(:a_third_field=)
    end
  end

  context "#reserved" do
    before(:each) do
      @t = TestClass.create
    end

    it "without existing reserved data" do
      @t.reserved.should be_nil
    end

    it "with existing reserved data" do
      FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
      @t.reload

      @t.reserved.should == {:some_field => "test"}
    end
  end

  context "#reserved=" do
    before(:each) do
      @t = TestClass.create
    end

    context "to a non-empty Hash" do
      it "without existing reserved data" do
        @t.reserved = {:some_field => "test"}
        @t.save!

        Reserve.count.should == 1
        Reserve.first.should have_attributes(
          :resource_type => @t.class.name,
          :resource_id   => @t.id,
          :reserved      => {:some_field => "test"}
        )
      end

      it "with existing reserved data" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved = {:some_field => "test2"}
        @t.save!

        Reserve.count.should == 1
        Reserve.first.should have_attributes(
          :resource_type => @t.class.name,
          :resource_id   => @t.id,
          :reserved      => {:some_field => "test2"}
        )
      end
    end

    context "to an empty Hash" do
      it "without existing reserved data" do
        @t.reserved = {}
        @t.save!

        Reserve.count.should == 0
      end

      it "with existing reserved data" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved = {}
        @t.save!

        Reserve.count.should == 0
      end
    end

    context "to nil" do
      it "without existing reserved data" do
        @t.reserved = nil
        @t.save!

        Reserve.count.should == 0
      end

      it "with existing reserved data" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved = nil
        @t.save!

        Reserve.count.should == 0
      end
    end
  end

  context "#reserved_hash_get" do
    before(:each) do
      @t = TestClass.create
    end

    it "without existing reserved data" do
      @t.reserved_hash_get(:some_field).should    be_nil
      @t.reserved_hash_get(:another_field).should be_nil
    end

    it "with existing reserved data" do
      FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
      @t.reload

      @t.reserved_hash_get(:some_field).should    == "test"
      @t.reserved_hash_get(:another_field).should be_nil
    end
  end

  context "#reserved_hash_set" do
    before(:each) do
      @t = TestClass.create
    end

    context "to a non-nil value" do
      it "without existing reserved data" do
        @t.reserved_hash_set(:some_field, "test")
        @t.save!

        Reserve.count.should == 1
        Reserve.first.should have_attributes(
          :resource_type => @t.class.name,
          :resource_id   => @t.id,
          :reserved      => {:some_field => "test"}
        )
      end

      context "with existing reserved data" do
        before(:each) do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
          @t.reload
        end

        it "updating an existing value" do
          @t.reserved_hash_set(:some_field, "test2")
          @t.save!

          Reserve.count.should == 1
          Reserve.first.should have_attributes(
            :resource_type => @t.class.name,
            :resource_id   => @t.id,
            :reserved      => {:some_field => "test2"}
          )
        end

        it "adding a new value" do
          @t.reserved_hash_set(:another_field, "test2")
          @t.save!

          Reserve.count.should == 1
          Reserve.first.should have_attributes(
            :resource_type => @t.class.name,
            :resource_id   => @t.id,
            :reserved      => {:some_field => "test", :another_field => "test2"}
          )
        end
      end
    end

    context "to nil" do
      it "without existing reserved data" do
        @t.reserved_hash_set(:some_field, nil)
        @t.save!

        Reserve.count.should == 0
      end

      context "with existing reserved data" do
        it "of only this attribute" do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
          @t.reload

          @t.reserved_hash_set(:some_field, nil)
          @t.save!

          Reserve.count.should == 0
        end

        it "of multiple attributes" do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test", :another_field => "test2"})
          @t.reload

          @t.reserved_hash_set(:some_field, nil)
          @t.save!

          Reserve.count.should == 1
          Reserve.first.should have_attributes(
            :resource_type => @t.class.name,
            :resource_id   => @t.id,
            :reserved      => {:another_field => "test2"}
          )
        end
      end
    end
  end

  context "#reserved_hash_migrate" do
    before(:each) do
      @t = TestClass.create
    end

    context "when the reserved key name matches the column name" do
      it "with a single key" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:name => "test"})
        @t.reload

        @t.reserved_hash_migrate(:name)

        Reserve.count.should == 0
        @t.name.should       == "test"
      end

      it "with multiple keys" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:name => "test", :description => "test2"})
        @t.reload

        @t.reserved_hash_migrate(:name, :description)

        Reserve.count.should  == 0
        @t.name.should        == "test"
        @t.description.should == "test2"
      end
    end

    context "when the reserved key name does not match the column name" do
      it "with a single key" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved_hash_migrate(:some_field => :name)

        Reserve.count.should == 0
        @t.name.should       == "test"
      end

      it "with multiple keys" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test", :another_field => "test2"})
        @t.reload

        @t.reserved_hash_migrate(:some_field => :name, :another_field => :description)

        Reserve.count.should  == 0
        @t.name.should        == "test"
        @t.description.should == "test2"
      end
    end
  end

  context "#save" do
    context "will touch the parent record's updated_on" do
      before(:each) do
        @t = TestClass.create
        @last_update = @t.updated_on
      end

      it "without existing reserved data" do
        @t.update_attribute(:some_field, "test")
        @t.updated_on.should_not == @last_update
      end

      context "with existing reserved data" do
        before(:each) do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
          @t.reload
        end

        it "and data changing" do
          @t.update_attribute(:some_field, "test2")
          @t.updated_on.should_not == @last_update
        end
      end
    end
  end
end
