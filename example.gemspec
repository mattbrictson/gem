require_relative "lib/example/version"

Gem::Specification.new do |spec|
  spec.name = "example"
  spec.version = Example::VERSION
  spec.authors = ["Example Owner"]
  spec.email = ["owner@example.com"]

  spec.summary = ""
  spec.homepage = "https://github.com/mattbrictson/gem"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/mattbrictson/gem/issues",
    "changelog_uri" => "https://github.com/mattbrictson/gem/releases",
    "source_code_uri" => "https://github.com/mattbrictson/gem",
    "homepage_uri" => spec.homepage
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = `git ls-files -z exe lib LICENSE.txt README.md`.split("\x0")
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
