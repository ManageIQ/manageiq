describe Vmdb::Plugins do
  it ".all" do
    all = described_class.all

    expect(all).to include(
      ManageIQ::Providers::Vmware::Engine,
      ManageIQ::UI::Classic::Engine
    )
    expect(all).to_not include(
      ActionCable::Engine
    )
  end

  it ".ansible_content" do
    ansible_content = described_class.ansible_content

    content = ansible_content.detect { |ac| ac.path.to_s.include?("manageiq-content") }
    expect(content.path).to eq ManageIQ::Content::Engine.root.join("content/ansible")

    content = ansible_content.detect { |ac| ac.path.to_s.include?("manageiq-ui-classic") }
    expect(content).to_not be
  end

  it ".automate_domains" do
    automate_domains = described_class.automate_domains

    domain = automate_domains.detect { |ac| ac.name == "ManageIQ" }
    expect(domain.path).to eq ManageIQ::Content::Engine.root.join("content/automate/ManageIQ")

    domain = automate_domains.detect { |ac| ac.path.to_s.include?("manageiq-ui-classic") }
    expect(domain).to_not be
  end

  it ".system_automate_domains" do
    automate_domains = described_class.system_automate_domains

    domain = automate_domains.detect { |ac| ac.name == "ManageIQ" }
    expect(domain.system?).to be_truthy

    domain = automate_domains.detect { |ac| ac.path.to_s.include?("manageiq-ui-classic") }
    expect(domain).to_not be
  end

  describe ".asset_paths" do
    it "with normal engines" do
      asset_paths = described_class.asset_paths

      asset_path = asset_paths.detect { |ap| ap.name == "ManageIQ::UI::Classic::Engine" }
      expect(asset_path.path).to eq ManageIQ::UI::Classic::Engine.root
      expect(asset_path.namespace).to eq "manageiq-ui-classic"
    end

    it "with engines with inflections" do
      asset_paths = described_class.asset_paths

      asset_path = asset_paths.detect { |ap| ap.name == "ManageIQ::V2V::Engine" }
      expect(asset_path.path).to eq ManageIQ::V2V::Engine.root
      expect(asset_path.namespace).to eq "manageiq-v2v"
    end
  end

  it ".provider_plugins" do
    provider_plugins = described_class.provider_plugins

    expect(provider_plugins).to include(
      ManageIQ::Providers::Vmware::Engine,
      ManageIQ::Providers::Amazon::Engine
    )
    expect(provider_plugins).to_not include(
      ManageIQ::Api::Engine,
      ManageIQ::UI::Classic::Engine
    )
  end
end
