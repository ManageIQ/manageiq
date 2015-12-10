require "spec_helper"

describe MiqReport do
  context "Seeding" do
    include_examples(".seed called multiple times", 129)
  end
end
