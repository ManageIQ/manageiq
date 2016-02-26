require 'miq_pglogical'

describe MiqPglogicalSubscriber do
  let(:subscriptions) do
    [
      {
        :dbname => "test_db",
        :host   => "example.com"
      },
      {
        :name   => "subscription_db_example_com",
        :dbname => "test_db2",
        :host   => "db.example.com"
      }
    ]
  end

  let(:subscription_names) { %w(subscription_db_example_com subscription_example_com) }

  before do
    MiqServer.seed
  end

  describe "#configured_subscriptions" do
    it "returns an empty array if no subscriptions are configured" do
      expect(subject.configured_subscriptions).to eq([])
    end

    context "with subscriptions" do
      before do
        c = MiqServer.my_server.get_config
        c.config.store_path(*described_class::SETTINGS_PATH, :subscriptions, subscriptions)
        c.save
      end

      it "names subscriptions without a name" do
        subject.configured_subscriptions.each do |s|
          expect(s[:name]).to eq("subscription_#{s[:host].gsub(/\.|-/, "_")}")
        end
      end
    end
  end

  describe "#refresh_subscriptions" do
    before do
      c = MiqServer.my_server.get_config
      c.config.store_path(*described_class::SETTINGS_PATH, :subscriptions, subscriptions)
      c.save
    end

    it "adds new subscriptions" do
      # no existing subscriptions
      pglogical = double(:subscriptions => [])
      allow(subject).to receive(:pglogical).and_return(pglogical)

      subscription_names.each do |name|
        expect(pglogical).to receive(:subscription_create).with(name, any_args)
      end
      subject.refresh_subscriptions
    end

    it "removes deleted subscriptions" do
      # more subscriptions than are configured
      more_subscriptions = [{"subscription_name" => "to_delete"}]
      subscription_names.each do |name|
        more_subscriptions << {"subscription_name" => name}
      end

      pglogical = double(:subscriptions => more_subscriptions)
      allow(subject).to receive(:pglogical).and_return(pglogical)

      expect(pglogical).to receive(:subscription_drop).with("to_delete")
      subject.refresh_subscriptions
    end
  end
end
