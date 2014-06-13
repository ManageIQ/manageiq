require "spec_helper"
require Rails.root.join("db/migrate/20120620215904_convert_old_states_to_new_format.rb")

describe ConvertOldStatesToNewFormat do
  migration_context :up do
    let(:state_stub) { migration_stub(:State) }

    shared_examples_for("states converted") do |filename|
      it filename do
        load_data_file(filename).each { |s| state_stub.create!(s) }

        disable_paralleism { migrate }

        actual   = state_stub.order(:id).all.collect { |s| s.data }
        expected = load_data_file("#{filename}_expected").collect { |e| e.to_yaml }

        actual.zip(expected).each_with_index do |(a, e), i|
          a.should eq(e), "on index #{i}"
        end
      end
    end

    context "converts old states to new format" do
      include_examples "states converted", "vm_linux"
      include_examples "states converted", "vm_windows"
      include_examples "states converted", "host"
    end

    it "cleans up bad states before migrating" do
      states = [
        state_stub.create!(:timestamp => 1.days.ago, :scantype => "diff"),
        state_stub.create!(:timestamp => 2.days.ago, :scantype => "full"),
        state_stub.create!(:timestamp => 3.days.ago, :scantype => "diff"),
        state_stub.create!(:timestamp => 4.days.ago, :scantype => "full"),
        state_stub.create!(:timestamp => 5.days.ago, :scantype => "diff"),
      ]
      expected_states = states[1, 2]

      described_class.any_instance.should_receive(:migrate_states_to_new_format).with(expected_states)

      disable_paralleism { migrate }

      state_stub.order(:id).all.should == expected_states
    end
  end

  private

  def load_data_file(filename = "")
    YAML.load_file(File.expand_path("data/#{File.basename(__FILE__, ".rb")}/#{filename}.yaml", File.dirname(__FILE__)))
  end

  def disable_paralleism
    old_val, ENV["MIGRATION_PROCESSES"] = ENV["MIGRATION_PROCESSES"], "0"
    yield
  ensure
    if old_val.nil?
      ENV.delete("MIGRATION_PROCESSES")
    else
      ENV["MIGRATION_PROCESSES"] = old_val
    end
  end
end
