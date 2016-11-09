# Describes TreeBuilderMenuRoles presenter
# Example tree:

# {
#   :key      => "xx-b__Report Menus for cloud-execs",
#   :title    => "Top Level",
#   :icon     => "/assets/100/folder.png",
#   :expand   => true,
#   :children => [
#     {
#       :key      => "xx-p__Configuration Management",
#       :title    => "Configuration Management",
#       :icon     => "/assets/100/folder.png",
#       :tooltip  => "Group: Configuration Management",
#       :children => [
#         {
#           :key      => "xx-s__Configuration Management:Virtual Machines",
#           :title    => "Virtual Machines",
#           :icon     => "/assets/100/folder.png",
#           :tooltip  => "Menu: Virtual Machines",
#           :children => [
#             {
#               :key          => "xx-VMs with Free Space > 50% by Department",
#               :title        => "VMs with Free Space &gt; 50% by Department",
#               :icon         => "/assets/100/report.png",
#               :cfmeNoClick  => true,
#               :expand       => nil
#             },
#             {
#               :key          => "xx-VMs w/Free Space > 75% by Function",
#               :title        => "VMs w/Free Space &gt; 75% by Function",
#               :icon         => "/assets/100/report.png",
#               :cfmeNoClick  => true,
#               :expand       => nil
#             }
#           ]
#         }
#       ]
#     }
#   ]
# }

describe TreeBuilderMenuRoles do
  let(:rpt_menu) do
    [
      [
        "Configuration Management", [
          ["Virtual Machines", ["VMs with Free Space > 50% by Department", "VMs w/Free Space > 75% by Function"]],
          ["Hosts", ["Hosts Summary", "Host Summary with VM info"]],
          ["Providers", ["Providers Summary", "Providers Hosts Relationships"]],
        ]
      ]
    ]
  end

  let(:sandbox) do
    { :rpt_menu => rpt_menu }
  end

  let(:instance) { TreeBuilderMenuRoles.new("menu_roles_tree", "menu_roles", sandbox, "cloud-execs") }

  describe "root node" do
    subject { instance.hash_tree.first }

    it 'has the correct key' do
      expect(subject[:key]).not_to be_nil
      expect(subject[:key]).to eq "xx-b__Report Menus for cloud-execs"
    end

    it 'has the correct title' do
      expect(subject[:title]).to eq "Top Level"
    end

    it 'has children' do
      expect(subject[:children]).not_to be_empty
    end
  end

  describe "1st level folder" do
    subject { instance.hash_tree.first[:children].first }

    it 'has the correct key' do
      expect(subject[:key]).not_to be_nil
      expect(subject[:key]).to eq "xx-p__Configuration Management"
    end

    it 'has children' do
      expect(subject[:children]).not_to be_empty
    end
  end

  describe "2nd level folder" do
    subject { instance.hash_tree.first[:children].first[:children].first }

    it 'has the correct key' do
      expect(subject[:key]).not_to be_nil
      expect(subject[:key]).to eq "xx-s__Configuration Management:Virtual Machines"
    end

    it 'has a key with parent name and colon' do
      expect(subject[:key]).to match(/Configuration\sManagement:/)
    end

    it 'has children' do
      expect(subject[:children]).not_to be_empty
    end
  end

  describe "report leaf node" do
    subject do
      instance.hash_tree.first[:children].first[:children].first[:children].first
    end

    it 'has the correct key' do
      expect(subject[:key]).not_to be_nil
      expect(subject[:key]).to eq "xx-VMs with Free Space > 50% by Department"
    end

    it 'is not clickable' do
      expect(subject[:cfmeNoClick]).to eq true
    end

    it 'has no children' do
      expect(subject[:children]).to be_nil
    end
  end

  describe "render locals" do
    subject { instance.locals_for_render }

    it 'includes a json tree' do
      parsed = JSON.parse(subject[:bs_tree])
      expect(parsed).to be_a_kind_of Array
    end

    it 'points to report/menu_editor' do
      expect(subject[:click_url]).to eq "/report/menu_editor/"
    end

    it 'uses miqMenuEditor to handle clicks' do
      expect(subject[:onclick]).to eq "miqMenuEditor"
    end
  end
end
