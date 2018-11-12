describe TaskHelpers::Exports::CustomizationTemplates do
  let(:template_name) { "Basic root pass template" }
  let(:template_type) { "CustomizationTemplateCloudInit" }
  let(:template_desc) { "This template takes use of rootpassword defined in the UI" }
  let(:template_script) { "#cloud-config\nchpasswd:\n  list: |\n    root:<%= MiqPassword.decrypt(evm[:root_password]) %>\n  expire: False" }
  let(:image_type_name1) { "CentOS-6" }
  let(:image_type_name2) { "RHEL-7" }
  let(:provision_type2) { "vm" }

  let(:content1) do
    { :name           => template_name,
      :description    => template_desc,
      :script         => template_script,
      :type           => template_type,
      :pxe_image_type => {
        :name => image_type_name1
      } }
  end

  let(:content2) do
    { :name           => template_name,
      :description    => template_desc,
      :script         => template_script,
      :type           => template_type,
      :pxe_image_type => {
        :name           => image_type_name2,
        :provision_type => provision_type2
      } }
  end

  let(:content3) do
    { :name           => template_name,
      :description    => template_desc,
      :script         => template_script,
      :type           => template_type,
      :system         => true,
      :pxe_image_type => {} }
  end

  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    pit1 = FactoryGirl.create(:pxe_image_type,
                              :name => image_type_name1)

    pit2 = FactoryGirl.create(:pxe_image_type,
                              :name           => image_type_name2,
                              :provision_type => provision_type2)

    FactoryGirl.create(:customization_template,
                       :name           => template_name,
                       :type           => template_type,
                       :description    => template_desc,
                       :script         => template_script,
                       :pxe_image_type => pit1)

    FactoryGirl.create(:customization_template,
                       :name           => template_name,
                       :type           => template_type,
                       :description    => template_desc,
                       :script         => template_script,
                       :pxe_image_type => pit2)

    CustomizationTemplate.create!(:name        => template_name,
                                  :type        => template_type,
                                  :description => template_desc,
                                  :system      => true,
                                  :script      => template_script)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  describe "when --all is not specified" do
    let(:template_filename1) { "#{export_dir}/#{image_type_name1}-Basic_root_pass_template.yaml" }
    let(:template_filename2) { "#{export_dir}/#{image_type_name2}-Basic_root_pass_template.yaml" }

    it 'exports user customization templates to a given directory with unique filenames' do
      TaskHelpers::Exports::CustomizationTemplates.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
      customization_template1 = YAML.load_file(template_filename1)
      expect(customization_template1).to eq(content1)
      customization_template2 = YAML.load_file(template_filename2)
      expect(customization_template2).to eq(content2)
    end
  end

  describe "when --all is specified" do
    let(:template_filename1) { "#{export_dir}/#{image_type_name1}-Basic_root_pass_template.yaml" }
    let(:template_filename2) { "#{export_dir}/#{image_type_name2}-Basic_root_pass_template.yaml" }
    let(:template_filename3) { "#{export_dir}/Examples-Basic_root_pass_template.yaml" }

    it 'exports all provision dialogs to a given directory with unique filenames' do
      TaskHelpers::Exports::CustomizationTemplates.new.export(:directory => export_dir, :all => true)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(3)
      customization_template1 = YAML.load_file(template_filename1)
      expect(customization_template1).to eq(content1)
      customization_template2 = YAML.load_file(template_filename2)
      expect(customization_template2).to eq(content2)
      customization_template3 = YAML.load_file(template_filename3)
      expect(customization_template3).to eq(content3)
    end
  end
end
