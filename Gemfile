source "https://rubygems.org"

rails_version = ENV["RAILS_VERSION"]
gem "activerecord", rails_version

sqlite_version = ENV["SQLITE_VERSION"]

unless sqlite_version.nil?
  gem "sqlite3", sqlite_version
end

gemspec
