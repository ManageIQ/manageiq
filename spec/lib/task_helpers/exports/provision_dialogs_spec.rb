RSpec.describe TaskHelpers::Exports::ProvisionDialogs do
  let(:dialog_name1) { "default_dialog" }
  let(:dialog_name2) { "custom_dialog" }
  let(:dialog_desc1) { "Default Provisioning Dialog" }
  let(:dialog_desc2) { "Custom Provisioning Dialog" }
  let(:dialog_type1) { "MiqProvisionWorkflow" }
  let(:dialog_type2) { "MiqProvisionWorkflow" }
  let(:dialog_type3) { "VmMigrateWorkflow" }

  let(:content) do
    {
      :dialogs => {
        :hardware => {
          :description => "Hardware",
          :fields      => {
            :disk_format => {
              :description => "Disk Format",
              :required    => false,
              :display     => :edit,
              :default     => "unchanged",
              :data_type   => :string,
              :values      => {
                :thick => "Thick",
                :thin  => "Thin"
              }
            },
            :cpu_limit   => {
              :description   => "CPU (MHz)",
              :required      => false,
              :notes         => "(-1 = Unlimited)",
              :display       => :edit,
              :data_type     => :integer,
              :notes_display => :show
            }
          }
        }
      }
    }
  end

  let(:content2) do
    {
      :dialogs => {
        :buttons => %i(submit cancel)
      }
    }
  end

  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    FactoryBot.create(:miq_dialog,
                       :dialog_type => dialog_type1,
                       :name        => dialog_name1,
                       :description => dialog_desc1,
                       :content     => content,
                       :default     => true)

    FactoryBot.create(:miq_dialog,
                       :dialog_type => dialog_type2,
                       :name        => dialog_name2,
                       :description => dialog_desc2,
                       :content     => content,
                       :default     => false)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  describe "when --all is not specified" do
    let(:dialog_filename1) { "#{export_dir}/#{dialog_type1}-custom_dialog.yaml" }
    let(:dialog_filename2) { "#{export_dir}/#{dialog_type3}-custom_dialog.yaml" }

    it 'exports user provision dialogs to a given directory' do
      TaskHelpers::Exports::ProvisionDialogs.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
      dialog = YAML.load_file(dialog_filename1)
      expect(dialog[:content]).to eq(content)
      expect(dialog[:description]).to eq(dialog_desc2)
    end
  end

  describe "when --all is specified" do
    let(:dialog_filename1) { "#{export_dir}/#{dialog_type1}-default_dialog.yaml" }
    let(:dialog_filename2) { "#{export_dir}/#{dialog_type1}-custom_dialog.yaml" }

    it 'exports all provision dialogs to a given directory' do
      TaskHelpers::Exports::ProvisionDialogs.new.export(:directory => export_dir, :all => true)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
      dialog1 = YAML.load_file(dialog_filename1)
      dialog2 = YAML.load_file(dialog_filename2)
      expect(dialog1[:content]).to eq(content)
      expect(dialog1[:description]).to eq(dialog_desc1)
      expect(dialog2[:content]).to eq(content)
      expect(dialog2[:description]).to eq(dialog_desc2)
    end
  end

  describe "when multiple dialogs of different types have the same name" do
    let(:dialog_filename1) { "#{export_dir}/#{dialog_type1}-custom_dialog.yaml" }
    let(:dialog_filename2) { "#{export_dir}/#{dialog_type3}-custom_dialog.yaml" }

    before do
      FactoryBot.create(:miq_dialog,
                         :dialog_type => dialog_type3,
                         :name        => dialog_name2,
                         :description => dialog_desc2,
                         :content     => content2,
                         :default     => false)
    end

    it 'exports the dialogs to different files' do
      TaskHelpers::Exports::ProvisionDialogs.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
      dialog = YAML.load_file(dialog_filename1)
      expect(dialog[:content]).to eq(content)
      expect(dialog[:description]).to eq(dialog_desc2)
      dialog2 = YAML.load_file(dialog_filename2)
      expect(dialog2[:content]).to eq(content2)
      expect(dialog2[:description]).to eq(dialog_desc2)
    end
  end
end
