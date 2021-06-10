# frozen_string_literal: true

require "example"
# require "discard"
# require "with_model"
# require "database_cleaner/active_record"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # config.before :suite do
  #   ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
  # end

  # config.before :each do
  #   DatabaseCleaner.start
  # end

  # config.after :each do
  #   DatabaseCleaner.clean
  # end

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
  # config.extend WithModel

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
