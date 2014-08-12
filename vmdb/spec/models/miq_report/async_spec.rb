require "spec_helper"

describe MiqReport do
  context "Generator::Async" do
    context "._async_generate_tables" do
      it "unknown taskid" do
        -> { MiqReport._async_generate_tables(111111)}.should raise_error(MiqException::Error)
      end

      it "known taskid" do
        task = MiqTask.create
        -> { MiqReport._async_generate_tables(task.id)}.should_not raise_error
      end
    end
  end
end
