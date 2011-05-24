class RubyBamboo
  require File.join(File.dirname(__FILE__), 'utils')
  require File.join(File.dirname(__FILE__), 'gem_manifest')
  require File.join(File.dirname(__FILE__), 'rails_actions')
  require File.join(File.dirname(__FILE__), 'addons')

  include RailsActions
  include Addons

  def self.load
    require "rubygems"
    require "rush"
    require "system_timer"
  end

  def self.init
    RubyBamboo::Addons.pull_all
    RubyBamboo::RailsActions.pull_all
  end

  attr_reader :repo_dir, :build_dir, :head, :prev, :stack, :requested_stack, :env, :heroku_log_token, :addons, :addons_stacks
  attr_reader :language_pack

  def initialize(args)
    @build_dir = Rush[args[:build_dir] + "/"]
    @repo_dir = Rush[args[:repo_dir] + "/"]
    @head = args[:head]
    @prev = args[:prev]
    @stack = args[:stack]
    @requested_stack = args[:requested_stack]
    @env = args[:env]
    @heroku_log_token = args[:heroku_log_token]
    @addons = args[:addons]
    @addons_stacks = args[:addons_stacks]
  end

  def major_stack
    target_stack.split("-")[0]
  end

  def migrating_stacks?
    requested_stack and requested_stack != stack
  end

  def is_stack?(s)
    major_stack == s.to_s
  end

  def target_stack
    requested_stack || stack
  end

  def message(txt)
    Utils.message(txt)
  end

  def language_pack
    @language_pack ||=
      if build_dir["config/environment.rb"].exists? && build_dir["config/boot.rb"].exists?
        :rails
      elsif build_dir["config.ru"].exists? || build_dir["config/rackup.ru"].exists?
        grep = build_dir.bash("grep -E 'require .*sinatra.*' *.rb") rescue ''
        grep += build_dir.bash("grep -E 'require .*sinatra.*' *.ru") rescue ''
        grep.empty? ? :rack : :sinatra
      end
  end

  def use?
    !!language_pack
  end

  def name
    language_pack.to_s.capitalize
  end

  def default_process_types
    {"web" => "thin -p $PORT -e $RACK_ENV -R $HEROKU_RACK start",
     "worker" => "rake jobs:work"}
  end

  def config_vars
    nil
  end

  def minor_stack
    target_stack.split("-")[1..-1].join("-")
  end

  RUBY_STACKS = %w{aspen-mri-1.8.6 bamboo-ree-1.8.7 bamboo-edge bamboo-mri-1.9.1 bamboo-mri-1.9.2}
  def compile
    if RUBY_STACKS.include?(target_stack)
      run_rails_actions
      build_gems_manifest
      build_bundler
      ruby_prune_build_dir
      copy_prebuilt_gems
      install_addons
      workaround_ruby_permissions_bugs
      ruby_finalize
    end
  end

  def ruby_finalize
    # move gems_build to gems so that it's cached for the next push.
    if gems_build_dir.exists?
      gems_cache_dir.destroy if gems_cache_dir.exists?
      FileUtils.mv gems_build_dir.to_s, gems_cache_dir.to_s
    end
  end

  def workaround_ruby_permissions_bugs
    # add world readability to work around a bug in File#readable? in aspen
    # and File::Stat#readable? in 1.8
    return unless %w( aspen-mri-1.8.6 bamboo-ree-1.8.7 ).include?(target_stack)
    build_dir.bash "find . -mindepth 1 -perm -u=r -not -type l -print0 | xargs -0 chmod o+r"
  end

  def ruby_prune_build_dir
    %w[.gems].each do |path|
      build_dir[path].destroy
    end
  end

  def gemfile
    build_dir['Gemfile']
  end

  def bundle_path
    ".bundle/gems/"
  end

  def bundler_gems
    build_dir[bundle_path]
  end

  def bundler_config
    build_dir['.bundle/config']
  end

  def bundled_gems_cache
    repo_dir['bundled_gems/']
  end

  def bundler_dir_cache
    repo_dir["cache/#{stack}/ruby/bundler/"]
  end

  def bundler_config_cache
    bundler_dir_cache['config']
  end

  def copy_prebuilt_gems
    if gems_build_dir.exists?
      gems_build_dir.copy_to build_dir['.gems/']
    elsif gems_cache_dir.exists?
      gems_cache_dir.copy_to build_dir['.gems/']
    end
  end

  def build_gems_manifest
    GemManifest::Runner.new(self).run(:force => migrating_stacks?, :force_gems => @force_gems)
  end

  def user_bundle_without
    env["BUNDLE_WITHOUT"]
  end

  def build_bundler
    if (wrong_case_gemfile = build_dir.files.find { |f| s, t = f.name, gemfile.name; s.casecmp(t).zero? && s != t })
      raise Slug::CompileError, "Bundler requires 'Gemfile' to be capitalized, but the file in your repository is called '#{wrong_case_gemfile.name}'"
    end

    return unless gemfile.exists?
    # run the bundler command straight from the corresponding ruby vm bin folder
    bundle_cmd = "export PATH=#{ruby_path}; #{bundle_bin}"
    bundle_version = Rush.bash("#{bundle_cmd} version").strip

    message "-----> Gemfile detected, running #{bundle_version}\n"
    if is_stack?('aspen')
      message "-----> Bundler works best on the Bamboo stack.  Please migrate your app:\n"
      message "       http://devcenter.heroku.com/articles/bamboo\n"
    end

    git_dir = ENV.delete('GIT_DIR') # avoid conflict - bundler also calls git
    ENV.delete('BUNDLE_GEMFILE')

    if migrating_stacks?
      bundled_gems_cache.destroy
      bundler_config_cache.destroy
    end

    if bundled_gems_cache.exists? && !bundled_gems_cache.entries.empty?
      bundler_gems.create
      Rush.bash "cp -R #{bundled_gems_cache}* #{bundler_gems.to_s.chomp('/')}"
    end

    if bundle_without = user_bundle_without
      bundle_without.gsub!(/[^a-z :]/, '')
      bundle_without.gsub!(/ /, ':')
    end

    if bundler_config_cache.exists?
      build_dir['.bundle/'].create unless build_dir['.bundle'].exists?
      Rush.bash "cp #{bundler_config_cache} #{bundler_config}"

      # need to update BUNDLE_WITHOUT before bundle check
      old_bundler_config = YAML.load_file(bundler_config.to_s)
      old_bundler_config["BUNDLE_WITHOUT"] = bundle_without
      bundler_config.write(old_bundler_config.to_yaml)
    end

    begin
      check = Rush.bash("cd #{build_dir.full_path} && #{bundle_cmd} check")
      gemfile_updated = !repo_dir.bash("git diff #{prev} #{head} -- Gemfile").empty?
    rescue Rush::BashFailed => e
      check = false
      gemfile_updated = false
    end

    if check && !gemfile_updated
      message "       All dependencies are satisfied\n"
    else
      message "       Unresolved dependencies detected; Installing...\n"

      bundler_gems.destroy # bundler doesn't remove unused gems
      bundler_gems.create

      # --deployment overwrites BUNDLE_PATH, so need to use --path
      command = "cd #{build_dir.full_path} && #{bundle_cmd} install --path #{bundle_path}"

      if bundle_without && bundle_without.any?
        message "       Using --without #{bundle_without}\n"
        command += " --without #{bundle_without}"
      end

      lock_file = build_dir['Gemfile.lock']
      if lock_file.exists? # bundler 1.0 likes the lock in git
        if lock_file.read =~ /^PLATFORMS\s+.*(mingw|mswin)/ # get rid of lock if generated on Windows
          lock_file.destroy
          message "       Windows Gemfile.lock detected, ignoring it.\n"
        else
          command += " --deployment"
        end
      else
        message "\n"
        message " !     Gemfile.lock will soon be required\n"
        message " !     Check Gemfile.lock into git with `git add Gemfile.lock`\n"
        message " !     See http://devcenter.heroku.com/articles/bundler\n"
        message "\n"
      end

      retval = Utils.spawn_nobuffer(command)
      if retval != 0
        message "       FAILED: http://devcenter.heroku.com/articles/bundler\n"
        raise Slug::CompileError, "failed to install gems via Bundler"
      end
    end

    if bundler_gems.exists?
      bundled_gems_cache.destroy
      bundled_gems_cache.create
      Rush.bash "cp -r #{bundler_gems}* #{bundled_gems_cache.to_s.chomp('/')}"

      bundler_gems['**/*.gem'].each { |gem| gem.destroy }
      bundler_gems['cache/'].destroy
    end

    # cache config
    bundler_dir_cache.create unless bundler_dir_cache.exists?
    Rush.bash "cp #{bundler_config} #{bundler_config_cache.to_s}"

    ENV['GIT_DIR'] = git_dir
  end

  def ruby_vm
    minor_stack || 'mri-1.8.6'
  end

  def ruby_path
    base = "/usr/local/bin:/usr/bin:/bin"
    case ruby_vm
    when 'ree-1.8.7' then "/usr/ruby1.8.7/bin:#{base}"
    when 'mri-1.8.7' then "/usr/ruby1.8.7/bin:#{base}"
    when 'mri-1.9.1' then "/usr/ruby1.9.1/bin:#{base}"
    when 'mri-1.9.2' then "/usr/ruby1.9.2/bin:#{base}"
    when 'edge'      then "$PATH"      # for running slugc tests locally
    else "/usr/ruby1.8.6/bin:#{base}"
    end
  end

  def bundle_bin
    Rush.bash("export PATH=#{ruby_path}; which bundle").strip
  end

  def gems_build_dir
    repo_dir['gems_build/']
  end

  def gems_cache_dir
    repo_dir['gems/']
  end

  def installed_gems
    gems = []

    if build_dir["Gemfile"].exists?
      gems.concat(build_dir.bash("#{bundle_bin} show | grep \"^  *\" | cut -d' ' -f4").split("\n"))
    end

    if build_dir[".gems"].exists?
      gems.concat(build_dir.bash("#{bundle_bin} show | grep \"^  *\" | cut -d' ' -f4").split("\n"))
    end

    gems
  rescue
    []
  end
end
