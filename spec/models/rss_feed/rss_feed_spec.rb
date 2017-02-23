describe RssFeed do
  Y_DIR = File.expand_path(File.join(File.dirname(__FILE__), "data"))

  before(:each) { Kernel.silence_warnings { RssFeed.const_set(:YML_DIR, Y_DIR) } }

  context "with vms" do
    before do
      Tenant.seed
      allow(User).to receive_messages(:server_timezone => "UTC")
      RssFeed.sync_from_yml_file("newest_vms")
    end

    let(:owner_tenant)    { FactoryGirl.create(:tenant) }
    let(:owner_group)     { FactoryGirl.create(:miq_group, :tenant => owner_tenant) }
    let(:owner_user)      { FactoryGirl.create(:user, :miq_groups => [owner_group]) }
    let!(:owned_vm)       { FactoryGirl.create(:vm_vmware, :tenant => owner_tenant) }
    let!(:tenant_root_vm) { FactoryGirl.create(:vm_vmware, :tenant => Tenant.root_tenant) }
    let(:rss_feed)        { RssFeed.find_by(:name => "newest_vms") }

    it "#generate 1 vms with owner_tenant tenant in newest_vms rss" do
      [owner_group, owner_user].each do |user_or_group|
        User.with_user(owner_user) do
          feed_container = rss_feed.generate(nil, nil, nil, user_or_group)

          expect(feed_container[:text]).to eq <<-EOXML
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rss version=\"2.0\">
  <channel>
    <title>Recently Discovered VMs</title>
    <link>https://localhost:3000/alert/rss?feed=newest_vms</link>
    <description>Virtual machines added</description>
    <language>en-us</language>
    <ttl>40</ttl>
    <item>
      <title>#{owned_vm.name} - location unknown</title>
      <description>#{owned_vm.name} is a #{owned_vm.vendor_display} VM located at "#{owned_vm.location}"</description>
      <pubDate>#{owned_vm.created_on.rfc2822}</pubDate>
      <guid>https://localhost:3000/vm/show/#{owned_vm.id}</guid>
      <link>https://localhost:3000/vm/show/#{owned_vm.id}</link>
    </item>
  </channel>
</rss>
          EOXML

          expect(feed_container[:content_type]).to eq('application/rss+xml')
        end
      end
    end
  end

  context "with 2 hosts" do
    before(:each) do
      @host1 = FactoryGirl.create(:host,           :created_on => Time.utc(2013, 1, 1, 0, 0, 0))
      @host2 = FactoryGirl.create(:host_microsoft, :created_on => @host1.created_on + 1.second)
    end

    it "#generate 2 hosts in newest_hosts rss" do
      RssFeed.sync_from_yml_file("newest_hosts")
      feed_container = RssFeed.where(:name => "newest_hosts").first.generate
      expect(feed_container[:text]).to eq <<-EOXML
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rss version=\"2.0\">
  <channel>
    <title>Recently Added Hosts</title>
    <link>https://localhost:3000/alert/rss?feed=newest_hosts</link>
    <description>Host machines added</description>
    <language>en-us</language>
    <ttl>40</ttl>
    <item>
      <title>#{@host2.name}, hostname: #{@host2.hostname}, running Microsoft VMM</title>
      <description>#{@host2.name}, hostname: #{@host2.hostname}</description>
      <pubDate>#{@host2.created_on.rfc2822}</pubDate>
      <guid>https://localhost:3000/host/show/#{@host2.id}</guid>
      <link>https://localhost:3000/host/show/#{@host2.id}</link>
    </item>
    <item>
      <title>#{@host1.name}, hostname: #{@host1.hostname}, running VMware VMM</title>
      <description>#{@host1.name}, hostname: #{@host1.hostname}</description>
      <pubDate>#{@host1.created_on.rfc2822}</pubDate>
      <guid>https://localhost:3000/host/show/#{@host1.id}</guid>
      <link>https://localhost:3000/host/show/#{@host1.id}</link>
    </item>
  </channel>
</rss>
EOXML
      expect(feed_container[:content_type]).to eq('application/rss+xml')
    end
  end

  context ".sync_from_yml_dir" do
    before(:each) do
      RssFeed.seed
    end

    it "loads the files from the yaml directory" do
      expect(RssFeed.count).to eq(Dir.glob(File.join(Y_DIR, "*.yml")).count)
    end

    it "when new yaml file is added" do
      all_files = Dir.glob(File.join(Y_DIR, "*.yml")) + [File.join(Y_DIR, "test.yml")]
      allow(Dir).to receive(:glob).and_return(all_files)

      expect(described_class).to receive(:sync_from_yml_file).exactly(all_files.length).times
      described_class.sync_from_yml_dir
    end

    it "when a yaml file is deleted" do
      expect(RssFeed.count).to be > 0

      allow(File).to receive(:exist?).and_return(false)
      described_class.sync_from_yml_dir
      expect(RssFeed.count).to eq(0)
    end
  end

  include_examples(".seed called multiple times", 2)

  context ".sync_from_yml_file" do
    before(:each) { @name = "newest_hosts" }

    it "when the model does not exist" do
      described_class.sync_from_yml_file(@name)
      expect(RssFeed.count).to eq(1)
    end

    it "when the yaml file is updated" do
      RssFeed.seed
      original_time = RssFeed.find_by(:name => @name).yml_file_mtime
      old_count = RssFeed.count

      NEW_YML_FILE = <<-EOF
        roles: "change_managers"
        feed_title: "new_title"
        feed_description: "new_description"
        feed_link: "/alert/rss?feed=newest_hosts"
        EOF

      allow(File).to receive_messages(:mtime => original_time + 1)
      allow(File).to receive(:read).and_return(NEW_YML_FILE)

      described_class.sync_from_yml_file(@name)
      expect(RssFeed.count).to eq(old_count)

      feed = RssFeed.find_by_name(@name)
      expect(feed.title).to eq("new_title")
      expect(feed.description).to eq("new_description")
    end
  end
end
