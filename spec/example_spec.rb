# frozen_string_literal: true

require "spec_helper"

RSpec.describe Example do
  it "has a version number" do
    expect(Example::VERSION).not_to be nil
  end
end
