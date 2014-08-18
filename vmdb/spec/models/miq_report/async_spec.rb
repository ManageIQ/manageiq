require "spec_helper"

describe MiqReport do
  context "Generator::Async" do
    context "._async_generate_tables" do
      it "unknown taskid" do
        expect { MiqReport._async_generate_tables(111111, :reports => [])}.to raise_error(MiqException::Error)
      end

      it "known taskid" do
        task = MiqTask.create
        expect { MiqReport._async_generate_tables(task.id, :reports => [])}.not_to raise_error
      end
    end
  end
end
