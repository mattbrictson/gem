require_relative "lib/example/version"

Gem::Specification.new do |spec|
  spec.name = "example"
  spec.version = Example::VERSION
  spec.authors = ["Example Owner"]
  spec.email = ["owner@example.com"]

  spec.summary = ""
  spec.homepage = "https://github.com/CompanyCam/gemplate"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/CompanyCam/gemplate/issues",
    "changelog_uri" => "https://github.com/CompanyCam/gemplate/releases",
    "source_code_uri" => "https://github.com/CompanyCam/gemplate",
    "homepage_uri" => spec.homepage
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[LICENSE.txt README.md {exe,lib}/**/*]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # spec.add_dependency "activerecord", ">= 4.2", "< 7"
  # spec.add_dependency "activesupport", ">= 4.2", "< 7"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec", ">= 3.5.0"
  # spec.add_development_dependency "database_cleaner-active_record", "~> 2.0"
  # spec.add_development_dependency "with_model", "~> 2.0"
  spec.add_development_dependency "sqlite3"
end
