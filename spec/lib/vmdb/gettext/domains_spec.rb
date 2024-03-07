RSpec.describe Vmdb::Gettext::Domains do
  context ".add_domain" do
    let(:name) { "test" }
    let(:path) { "/dev/null" }

    it "sets mo_paths" do
      described_class.add_domain(name, path, :mo)
      expect(described_class.mo_paths).to include(path)
    end

    it "sets po_paths" do
      described_class.add_domain(name, path, :po)
      expect(described_class.po_paths).to include(path)
    end

    it "sets paths independent from each other" do
      path2 = "/dev/zero"
      described_class.add_domain(name, path, :mo)
      described_class.add_domain(name, path2, :po)
      expect(described_class.mo_paths.count(path)).to eq(1)
      expect(described_class.po_paths.count(path2)).to eq(1)
    end

    it "paths contain no duplicates" do
      described_class.add_domain(name, path, :mo)
      described_class.add_domain(name, path, :mo)
      described_class.add_domain(name, path, :po)
      described_class.add_domain(name, path, :po)

      expect(described_class.mo_paths.count(path)).to eq(1)
      expect(described_class.po_paths.count(path)).to eq(1)
    end
  end
end
