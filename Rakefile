require "fileutils"

def vendor_base(dir)
  File.expand_path("../vendor/#{dir}", __FILE__)
end

def vendor_plugin(git_url)
  name = File.basename(git_url, File.extname(git_url))
  Dir.chdir(vendor_base("plugins")) do
    FileUtils.rm_rf(name)
    sh "git clone #{git_url} #{name}"
    FileUtils.rm_rf("#{name}/.git")
  end
end

def vendor_addon(name, hash)
  git_url = hash[:url]
  tag = hash[:tag]
  name = name.to_s
  # name = File.basename(git_url, File.extname(git_url))
  Dir.chdir(vendor_base("addons")) do
    FileUtils.rm_rf(name)
    sh "git clone #{git_url} #{name}"
    sh "cd #{name} && git remote update && git checkout refs/tags/#{tag}" if tag
    FileUtils.rm_rf("#{name}/.git")
  end
end

desc "update plugins"
task "plugins:update" do
  require File.join(File.dirname(__FILE__), "lib", "ruby_bamboo")
  sh "mkdir -p #{vendor_base("plugins").to_s}"
  sh "mkdir -p #{vendor_base("addons").to_s}"
  RubyBamboo::RailsActions::PLUGINS.values.each {|git_url| vendor_plugin(git_url) }
  RubyBamboo::Addons::ADDONS_REPOS.each  {|name, hash| vendor_addon(name, hash) }
end
