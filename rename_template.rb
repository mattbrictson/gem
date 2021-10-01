#!/usr/bin/env ruby

require "bundler/inline"
require "fileutils"
require "io/console"
require "open3"

gemfile do
  source "https://rubygems.org"
  gem "octokit", "~> 4.14"
end

def main # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  assert_git_repo!
  git_meta = read_git_data

  gem_name = ask("Gem name?", default: git_meta[:origin_repo_name])
  gem_summary = ask("Gem summary (< 60 chars)?", default: "")
  author_email = ask("Author email?", default: git_meta[:user_email])
  author_name = ask("Author name?", default: git_meta[:user_name])
  github_repo = ask("GitHub repository?", default: git_meta[:origin_repo_path])
  exe = ask_yes_or_no("Include an executable (CLI) in this gem?", default: "N")

  if ask_yes_or_no("Create GitHub labels?", default: "Y")
    puts
    puts "I need to ask for your GitHub credentials in order to create labels."
    puts "Don't worry, your GitHub credentials will NOT be saved."
    puts
    login = ask("GitHub username?", default: github_repo.split("/").first)
    password = ask("GitHub password?", echo: false)
    client = authenticate_github(login, password)
    create_labels(
      client,
      github_repo,
      ["automerge", "fbca04", "Automatically merge PR once all required checks pass"],
      ["⚠️ Breaking", "d12d1b", "Introduces a backwards-incompatible change"],
      ["🐛 Bug Fix", "c0fc80", "Fixes a bug"],
      ["📚 Docs", "bfdadc", "Improves documentation"],
      ["✨ Feature", "ba1ecc", "Adds a new feature"],
      ["🏠 Housekeeping", "ccccff", "Non-user facing cleanup and maintenance"]
    )
  end

  git "mv", ".github/workflows/push.yml.dist", ".github/workflows/push.yml"

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
                  "Example::VERSION" => "#{as_module(gem_name)}::VERSION",
                  /summary\s*=\s*("")/ => gem_summary.inspect

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
  text = File.read(file)
  text = text.lines.filter.grep_v(pattern).join
  File.write(file, text)
  git "add", file
end

def ask(question, default: nil, echo: true)
  prompt = "#{question} "
  prompt << "[#{default}] " unless default.nil?
  print prompt
  answer = if echo
             $stdin.gets.chomp
           else
             $stdin.noecho(&:gets).tap { $stdout.print "\n" }.chomp
           end
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
  contents = File.read(path)
  replacements.each do |regexp, text|
    contents.gsub!(regexp) do |match|
      next text if Regexp.last_match(1).nil?

      match[regexp, 1] = text
      match
    end
  end

  File.write(path, contents)
  git "add", path
end

def as_path(gem_name)
  gem_name.tr("-", "/")
end

def as_module(gem_name)
  parts = gem_name.split("-")
  parts.map do |part|
    part.gsub(/^[a-z]|_[a-z]/) { |str| str[-1].upcase }
  end.join("::")
end

def reindent_module(path)
  contents = File.read(path)
  namespace_mod = contents[/(?:module|class) (\S+)/, 1]
  return unless namespace_mod.include?("::")

  contents.sub!(namespace_mod, namespace_mod.split("::").last)
  namespace_mod.split("::")[0...-1].reverse_each do |mod|
    contents = "module #{mod}\n#{contents.gsub(/^/, '  ')}end\n"
  end

  File.write(path, contents)
  git "add", path
end

def authenticate_github(login, password)
  octokit = Octokit::Client.new(login: login, password: password, netrc: false)
  octokit.user
  GithubClient.new(octokit)
rescue Octokit::OneTimePasswordRequired
  token = ask("2FA token?")
  GithubClient.new(octokit, otp_token: token)
end

def create_labels(client, github_repo, *labels)
  labels.each do |name, color, description|
    client.add_label(github_repo, name, color, description)
  end

  puts "Created labels: #{labels.map(&:first).join(', ')}"
end

class GithubClient
  def initialize(octokit, otp_token: nil)
    @octokit = octokit
    @otp_token = otp_token
  end

  def add_label(repo, name, color, description)
    octokit.add_label(
      repo,
      name,
      color,
      auth_options.merge(
        description: description,
        accept: "application/vnd.github.symmetra-preview+json"
      )
    )
  end

  private

  attr_reader :octokit, :otp_token

  def auth_options
    return {} if otp_token.nil?

    { headers: { "X-GitHub-OTP" => otp_token } }
  end
end

main if $PROGRAM_NAME == __FILE__
