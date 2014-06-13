require "spec_helper"

module MiqAeCollectSpec
  include MiqAeEngine
  describe "MiqAeCollect" do
    before(:each) do
      MiqAeDatastore.reset
      @domain = "SPEC_DOMAIN"
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "collect_data"), @domain)
    end

    after(:each) do
      MiqAeDatastore.reset
    end

    MONTHS = {"January"=>1, "October"=>10, "June"=>6, "July"=>7, "February"=>2, "May"=>5, "March"=>3, "December"=>12, "August"=>8, "September"=>9, "November"=>11, "April"=>4}
    it "collects months" do

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_months")
      ws.should_not be_nil

      #puts ws.to_xml
      months = ws.root("months")
      months.should_not be_nil
      months.class.to_s.should == "Hash"
      months.length.should     == 12
      months.should            == MONTHS
      ws.root('sort').should   == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
      ws.root('rsort').should  == [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
      ws.root('count').should  == 12
      ws.root('min').should    == 1
      ws.root('max').should    == 12
      ws.root('mean').should   == 6.5
    end

    WEEKDAYS = {"Wednesday"=>4, "Friday"=>6, "Saturday"=>7, "Tuesday"=>3, "Sunday"=>1, "Monday"=>2, "Thursday"=>5}
    it "collects weekdays" do

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_weekdays")
      ws.should_not be_nil
      #puts ws.to_xml
      weekdays = ws.root("weekdays")
      weekdays.should_not be_nil
      weekdays.class.to_s.should == "Hash"
      weekdays.length.should     == 7
      weekdays.should            == WEEKDAYS
      ws.root('sum').should      == 28
    end

    it "collect on instance level overrides collect on class level" do
      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/TEST", "COLLECT")
      i1 = c1.ae_instances.detect { |i| i.name == "INFO"   }
      f1 = c1.ae_fields.detect    { |f| f.name == "weekdays" }
      i1.set_field_collect(f1, "weekdays = [description]")

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_weekdays")
      ws.should_not be_nil
      #puts ws.to_xml
      weekdays = ws.root("weekdays")
      weekdays.should_not be_nil
      weekdays.class.to_s.should == "Array"
      weekdays.length.should     == 7
    end

    it "gets proper value base on environment" do

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=dev#get_random_number")
      ws.should_not be_nil
      ws.root("number").should == 3

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=test#get_random_number")
      ws.should_not be_nil
      ws.root("number").should == 5

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=foo#get_random_number")
      ws.should_not be_nil
      ws.root("number").should == 1
      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO?environment=#get_random_number")
      ws.should_not be_nil
      ws.root("number").should == 0

      ws = MiqAeEngine.instantiate("/TEST/COLLECT/INFO#get_random_number")
      ws.should_not be_nil
      ws.root("number").should == 0
    end

  end
end
