require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Sandbox do
  let(:sb) do
    Object.new.extend(Sandbox).tap { |sb| sb.instance_eval { @sb = {} } }
  end

  context '#x_active_tree=' do
    it "raises an exception on unknown tree" do
      expect { sb.x_active_tree = 'foobar' }.to raise_error(ActionController::RoutingError)
    end

    it "converts known trees to symbols and returns them when asked" do
      sb.x_active_tree = 'vmdb_tree'
      expect(sb.x_active_tree).to be(:vmdb_tree)
    end

    it "accepts nil tree and returns it when asked" do
      sb.x_active_tree = nil
      expect(sb.x_active_tree).to be_nil
    end
  end

  context '#x_active_accord=' do
    it "raises an exception on unknown accordion" do
      expect { sb.x_active_accord = 'foobar' }.to raise_error(ActionController::RoutingError)
    end

    it "converts known accordions to symbols and returns them when asked" do
      sb.x_active_accord = 'vmdb'
      expect(sb.x_active_accord).to be(:vmdb)
    end
  end
end
