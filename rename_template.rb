#!/usr/bin/env ruby

require "fileutils"
require "open3"

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
def main
  assert_git_repo!
  git_meta = read_git_data

  gem_name = ask("Gem name?", default: git_meta[:origin_repo_name])
  author_email = ask("Author email?", default: git_meta[:user_email])
  author_name = ask("Author name?", default: git_meta[:user_name])
  github_repo = ask("GitHub repository?", default: git_meta[:origin_repo_path])
  exe = ask_yes_or_no("Include an executable (CLI) in this gem?", default: "N")

  git "mv", ".github/main.workflow.dist", ".github/main.workflow"

  FileUtils.mkdir_p "lib/#{as_path(gem_name)}"
  FileUtils.mkdir_p "test/#{as_path(gem_name)}"

  ensure_executable "bin/console"
  ensure_executable "bin/setup"

  if exe
    replace_in_file "exe/example",
                    "example" => as_path(gem_name),
                    "Example" => as_module(gem_name)

    git "mv", "exe/example", "exe/#{gem_name}"
    ensure_executable "exe/#{gem_name}"

    replace_in_file "lib/example/cli.rb",
                    "Example" => as_module(gem_name)

    git "mv", "lib/example/cli.rb", "lib/#{as_path(gem_name)}/cli.rb"
    reindent_module "lib/#{as_path(gem_name)}/cli.rb"
  else
    git "rm", "exe/example", "lib/example/cli.rb"
    remove_line "lib/example.rb", /autoload :CLI/
  end

  replace_in_file "LICENSE.txt",
                  "Example Owner" => author_name

  replace_in_file "Rakefile",
                  "example.gemspec" => "#{gem_name}.gemspec",
                  "mattbrictson/gem" => github_repo

  replace_in_file "README.md",
                  "mattbrictson/gem" => github_repo,
                  'require "example"' => %Q(require "#{as_path(gem_name)}"),
                  "example" => gem_name,
                  "replace_with_gem_name" => gem_name,
                  /\A.*<!-- END FRONT MATTER -->\n+/m => ""

  replace_in_file "CHANGELOG.md",
                  "mattbrictson/gem" => github_repo

  replace_in_file "CODE_OF_CONDUCT.md",
                  "owner@example.com" => author_email

  replace_in_file "bin/console",
                  'require "example"' => %Q(require "#{as_path(gem_name)}")

  replace_in_file "example.gemspec",
                  "mattbrictson/gem" => github_repo,
                  '"Example Owner"' => author_name.inspect,
                  '"owner@example.com"' => author_email.inspect,
                  '"example"' => gem_name.inspect,
                  "example/version" => "#{as_path(gem_name)}/version",
                  "Example::VERSION" => "#{as_module(gem_name)}::VERSION"

  git "mv", "example.gemspec", "#{gem_name}.gemspec"

  replace_in_file "lib/example.rb",
                  "example" => as_path(gem_name),
                  "Example" => as_module(gem_name)

  git "mv", "lib/example.rb", "lib/#{as_path(gem_name)}.rb"
  reindent_module "lib/#{as_path(gem_name)}.rb"

  replace_in_file "lib/example/version.rb",
                  "Example" => as_module(gem_name)

  git "mv", "lib/example/version.rb", "lib/#{as_path(gem_name)}/version.rb"
  reindent_module "lib/#{as_path(gem_name)}/version.rb"

  replace_in_file "test/example_test.rb",
                  "Example" => as_module(gem_name)

  git "mv", "test/example_test.rb", "test/#{as_path(gem_name)}_test.rb"

  replace_in_file "test/test_helper.rb",
                  'require "example"' => %Q(require "#{as_path(gem_name)}")

  git "rm", "rename_template.rb"

  puts <<~MESSAGE

    All set!

    The project has been renamed from "example" to "#{gem_name}".
    Review the changes and then run:

      git commit && git push

  MESSAGE
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength

def assert_git_repo!
  return if File.file?(".git/config")

  warn("This doesn't appear to be a git repo. Can't continue. :(")
  exit(1)
end

def git(*args)
  sh! "git", *args
end

def ensure_executable(path)
  return if File.executable?(path)

  FileUtils.chmod 0o755, path
  git "add", path
end

def sh!(*args)
  puts ">>>> #{args.join(' ')}"
  stdout, status = Open3.capture2(*args)
  raise("Failed to execute: #{args.join(' ')}") unless status.success?

  stdout
end

def remove_line(file, pattern)
  text = IO.read(file)
  text = text.lines.filter.grep_v(pattern).join
  IO.write(file, text)
  git "add", file
end

def ask(question, default: nil)
  prompt = "#{question} "
  prompt << "[#{default}] " unless default.nil?
  print prompt
  answer = $stdin.gets.chomp
  answer.to_s.strip.empty? ? default : answer
end

def ask_yes_or_no(question, default: "N")
  default = default == "Y" ? "Y/n" : "y/N"
  answer = ask(question, default: default)

  answer != "y/N" && answer.match?(/^y/i)
end

def read_git_data
  return {} unless git("remote", "-v").match?(/^origin/)

  origin_url = git("remote", "get-url", "origin").chomp
  origin_repo_path = origin_url[%r{[:/]([^/]+/[^/]+)(?:\.git)$}, 1]

  {
    origin_repo_name: origin_repo_path.split("/").last,
    origin_repo_path: origin_repo_path,
    user_email: git("config", "user.email").chomp,
    user_name: git("config", "user.name").chomp
  }
end

def replace_in_file(path, replacements)
  contents = IO.read(path)
  replacements.each do |regexp, text|
    contents.gsub!(regexp) do |match|
      next text if Regexp.last_match(1).nil?

      match[regexp, 1] = text
      match
    end
  end

  IO.write(path, contents)
  git "add", path
end

def as_path(gem_name)
  gem_name.tr("-", "/")
end

def as_module(gem_name)
  parts = gem_name.split("-")
  parts.map do |part|
    part.gsub(/^[a-z]|_[a-z]/) { |str| str.chars.last.upcase }
  end.join("::")
end

def reindent_module(path)
  contents = IO.read(path)
  namespace_mod = contents[/(?:module|class) (\S+)/, 1]
  return unless namespace_mod.include?("::")

  contents.sub!(namespace_mod, namespace_mod.split("::").last)
  namespace_mod.split("::")[0...-1].reverse_each do |mod|
    contents = "module #{mod}\n#{contents.gsub(/^/, '  ')}end\n"
  end

  IO.write(path, contents)
  git "add", path
end

main if $PROGRAM_NAME == __FILE__
