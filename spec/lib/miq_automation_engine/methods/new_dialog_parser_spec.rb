require "spec_helper"
require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Service/Provisioning/StateMachines/Methods.class/__methods__/dialog_parser')
require Rails.root.join('spec/support/miq_ae_mock_service')

describe DialogParser do
  let(:user)  { FactoryGirl.create(:user_with_group) }
  let(:stp_request) { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:stpr) {  MiqAeMethodService::MiqAeServiceServiceTemplateProvisionRequest.find(stp_request.id) }
  let(:workspace) { instance_double("MiqAeEngine::MiqAeWorkspace", :root => options, :persist_state_hash => {}) }

  let(:options) { {'service_template_provision_request' => stpr} }

  def create_tags
    FactoryGirl.create(:classification_department_with_tags)
    @array_name = "Array::dialog_tag_0_department"
    @dept_ids = Classification.find_by_description('Department').children.collect do |x|
      "Classification::#{x.id}"
    end.join(',')

    @dept_array = Classification.find_by_description('Department').children.collect(&:name)
  end

  def run_automate_method
    service = MiqAeMockService.new(options)
    DialogParser.new(service).main
  end

  def setup_and_run_method(dialog_hash)
    stp_request.options = stp_request.options.merge(:dialog => dialog_hash)
    stp_request.save
    run_automate_method
    stp_request.reload
  end

  def load_options
    YAML.load(stp_request.get_option(:parsed_dialog_options))
  end

  def load_tags
    YAML.load(stp_request.get_option(:parsed_dialog_tags))
  end

  context "parser" do
    it "with options tags and arrays" do
      create_tags
      dialog_hash = {'dialog_option_1_numero' => 'one', 'dialog_option_2_numero' => 'two',
                     'dialog_option_3_numero' => 'three', 'dialog_option_0_numero' => 'zero',
                     'dialog_tag_0_location' => 'NYC', 'dialog_tag_1_location' => 'BOM',
                     'dialog_tag_2_location' => 'EWR', @array_name => @dept_ids}

      parsed_dialog_options_hash = {1 => {:numero => "zero"},
                                    2 => {:numero => "zero"},
                                    3 => {:numero => "zero"},
                                    0 => {:numero => "zero"}}
      parsed_dialog_tags_hash = {0 => {:location => "NYC", :department => @dept_array},
                                 1 => {:location => "NYC", :department => @dept_array},
                                 2 => {:location => "NYC", :department => @dept_array}}

      setup_and_run_method(dialog_hash)
      pdo = load_options
      pdt = load_tags

      expect(pdo).to eql(parsed_dialog_options_hash)
      expect(pdt).to eql(parsed_dialog_tags_hash)
    end

    it "with password option" do
      dialog_hash = {'password::dialog_option_1_passwordtest' => "v2:{i7uvqmb1Dr6WAxCpakNE9w==}"}
      parsed_dialog_options_hash = {1 => {:"password::dialog_passwordtest" => "v2:{i7uvqmb1Dr6WAxCpakNE9w==}",
                                          :"password::passwordtest"        => "v2:{i7uvqmb1Dr6WAxCpakNE9w==}"}}
      setup_and_run_method(dialog_hash)
      pdo = load_options

      expect(pdo).to eql(parsed_dialog_options_hash)
    end

    it "with generic password" do
      dialog_hash = {'password::dialog_passwordtest' => "v2:{i7uvqmb1Dr6WAxCpakNE9w==}"}
      parsed_dialog_options_hash = {0 => {:"password::dialog_passwordtest" => "v2:{i7uvqmb1Dr6WAxCpakNE9w==}",
                                          :"password::passwordtest"        => "v2:{i7uvqmb1Dr6WAxCpakNE9w==}"}}
      setup_and_run_method(dialog_hash)
      pdo = load_options

      expect(pdo).to eql(parsed_dialog_options_hash)
    end

    it "with no dialogs set" do
      stp_request.options = stp_request.options.merge(:dialog => {})
      stp_request.save
      expect { run_automate_method }.not_to raise_exception
    end
  end
end
