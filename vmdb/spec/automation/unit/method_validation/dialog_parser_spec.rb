require "spec_helper"
include ServiceTemplateHelper

describe "DialogParser Automate Method" do
  before(:each) do
    @root_stp = FactoryGirl.create(:miq_request_task, :type => 'ServiceTemplateProvisionTask')
  end

  def run_automate_method
    attrs = []
    attrs << "ServiceTemplateProvisionTask::service_template_provision_task=#{@root_stp.id}"

    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Service/Provisioning/StateMachines&class=Methods" \
                            "&instance=DialogParser&" \
                            "#{attrs.join('&')}")
  end

  def create_tags
    FactoryGirl.create(:classification_department_with_tags)
    @array_name  = "Array::dialog_tag_0_department"
    @dept_ids = Classification.find_by_description('Department').children.collect do |x|
      "Classification::#{x.id}"
    end.join(',')

    @dept_array = Classification.find_by_description('Department').children.collect(&:name)
  end

  context "parser" do
    it "with options tags and arrays" do
      create_tags
      dialog_hash = {'dialog_option_1_numero' => 'one', 'dialog_option_2_numero' => 'two',
                     'dialog_option_3_numero' => 'three', 'dialog_option_0_numero' => 'zero',
                     'dialog_tag_0_location' => 'NYC', 'dialog_tag_1_location' => 'BOM',
                     'dialog_tag_2_location' => 'EWR', @array_name => @dept_ids}

      parsed_dialog_options_hash = {1 => {:numero => "one"},
                                    2 => {:numero => "two"},
                                    3 => {:numero => "three"},
                                    0 => {:numero => "zero"}}
      parsed_dialog_tags_hash = {0 => {:location => "NYC"},
                                 1 => {:location => "BOM"},
                                 2 => {:location => "EWR"}}

      @root_stp.options = @root_stp.options.merge(:dialog => dialog_hash)
      @root_stp.save
      run_automate_method
      @root_stp.reload

      pdo = YAML.load(@root_stp.get_option(:parsed_dialog_options))
      pdt = YAML.load(@root_stp.get_option(:parsed_dialog_tags))
      depts = pdt[0].delete(:department)
      expect(pdo).to eql(parsed_dialog_options_hash)
      expect(pdt).to eql(parsed_dialog_tags_hash)
      expect(depts).to match_array(@dept_array)
    end

    it "with no dialogs set" do
      @root_stp.options = @root_stp.options.merge(:dialog => {})
      @root_stp.save
      expect { run_automate_method }.to raise_exception
    end
  end
end
