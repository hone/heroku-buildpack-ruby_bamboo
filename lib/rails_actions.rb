require 'thread'

module RubyBamboo::RailsActions
  PLUGINS = {
    :caches_page_via_http       => 'git://github.com/pedro/caches_page_via_http.git',
    :rails3_serve_static_assets => 'git://github.com/pedro/rails3_serve_static_assets.git',
    :rails3_disable_x_sendfile  => 'git://github.com/hone/rails3_disable_x_sendfile.git',
    :rails_log_stdout           => 'git://github.com/ddollar/rails_log_stdout.git'
  }

  def self.plugins_dir
    Rush[File.join(File.expand_path(File.dirname(__FILE__)), "..", "vendor", "plugins/")]
  end

  def run_rails_actions
    if language_pack == :rails
      run_aspen_rails_checks
      run_bamboo_rails_checks
      install_caches_page_via_http
      install_rails3_serve_static_assets
      install_rails3_disable_x_sendfile
      install_rails_log_stdout
    end
  end

  def rails_version
    @rails_version ||= begin
      environment_rb = build_dir['config/environment.rb'].read
      m = environment_rb.match(/^\s*RAILS_GEM_VERSION\s*=\s*['"](\d\.\d+\.\d+)['"]/)
      m[1] if m
    end
  end

  def vendored_rails?
    build_dir['vendor/rails/'].exists?
  end

  def run_aspen_rails_checks
    return unless is_stack?('aspen')
    if rails_version && rails_version >= '2.3.6'
      message " !     This version of Rails is only supported on the Bamboo stack\n"
      message " !     Please migrate your app to Bamboo and push again.\n"
      message " !     See http://devcenter.heroku.com/articles/bamboo for more information\n"
      raise Slug::CompileError, "incompatible Rails version"
    end
  end

  def specifies_rails_gem
    match = (build_dir.bash "grep 'rails' .gems" rescue nil)
    match ||= (build_dir.bash "grep 'rails' Gemfile" rescue nil)
    !!match
  end

  def run_bamboo_rails_checks
    return unless is_stack?('bamboo')
    if !specifies_rails_gem && !vendored_rails?
      if rails_version
        schedule_install_rails
      else
        message " !     Heroku Bamboo does not include any Rails gems by default.\n"
        message " !     You'll need to declare it in either .gems or Gemfile.\n"
        message " !     See http://devcenter.heroku.com/articles/gems for details on specifying gems.\n"
        raise Slug::CompileError, "no Rails gem specified."
      end
    end
  end

  def schedule_install_rails
    message "-----> WARNING: Detected Rails is not declared in either .gems or Gemfile\n"
    message "       Scheduling the install of Rails #{rails_version}.\n"
    message "       See http://devcenter.heroku.com/articles/gems for details on specifying gems.\n"
    @force_gems = [{
      'name' => 'rails',
      'version' => rails_version,
      'source' => ['http://rubygems.org']}]
  end

  def install_caches_page_via_http_plugin_path
    RubyBamboo::RailsActions.plugins_dir['caches_page_via_http']
  end

  def install_caches_page_via_http
    return if env['SKIP_CACHES_PAGE_VIA_HTTP'] == 'true'
    match = begin
      build_dir.bash "grep 'caches_page' app/controllers/*.rb"
    rescue Rush::BashFailed
      ""
    end
    return if match.empty?
    return if build_dir['vendor/plugins/caches_page_via_http/'].exists?

    message "-----> Detected use of caches_page\n"
    message "       Installing caches_page_via_http plugin..."
    build_dir['vendor/plugins/'].create
    build_dir.bash "cp -R #{install_caches_page_via_http_plugin_path} vendor/plugins"
    system "chmod -R go+rx #{build_dir['vendor/']}"
    message " done\n"
  end

  def rails3_serve_static_assets_plugin_path
    RubyBamboo::RailsActions.plugins_dir['rails3_serve_static_assets']
  end

  def install_rails3_serve_static_assets
    return if build_dir['vendor/plugins/rails3_serve_static_assets/'].exists?
    env_file = "config/environments/#{env['RACK_ENV'] || 'production'}.rb"
    return unless build_dir[env_file].exists?
    return unless build_dir[env_file].contents =~ /config\.serve_static_assets\s+=\s+false/

    message "-----> Detected Rails is not set to serve static_assets\n"
    message "       Installing rails3_serve_static_assets..."
    build_dir['vendor/plugins/'].create
    build_dir.bash "cp -R #{rails3_serve_static_assets_plugin_path} vendor/plugins"
    system "chmod -R go+rx #{build_dir['vendor/']}"
    message " done\n"
  end

  def rails3_disable_x_sendfile_plugin_path
    RubyBamboo::RailsActions.plugins_dir['rails3_disable_x_sendfile']
  end

  def install_rails3_disable_x_sendfile
    return unless build_dir['config/application.rb'].exists?
    return unless build_dir['config/application.rb'].read =~ /Rails::Application/
    return if build_dir['vendor/plugins/rails3_disable_x_sendfile'].exists?

    message "-----> Configure Rails 3 to disable x-sendfile\n"
    message "       Installing rails3_disable_x_sendfile..."
    build_dir['vendor/plugins/'].create
    build_dir.bash "cp -R #{rails3_disable_x_sendfile_plugin_path} vendor/plugins"
    system "chmod -R go+rx #{build_dir['vendor/']}"
    message " done\n"
  end

  def rails_log_stdout_path
    RubyBamboo::RailsActions.plugins_dir['rails_log_stdout'].full_path
  end

  def install_rails_log_stdout
    return if build_dir['vendor/plugins/rails_log_stdout/'].exists?
    if heroku_log_token and File.directory?(rails_log_stdout_path)
      message "-----> Configure Rails to log to stdout\n"
      message "       Installing rails_log_stdout..."
      build_dir['vendor/plugins/'].create
      build_dir.bash "cp -R #{rails_log_stdout_path} vendor/plugins"
      system "chmod -R go+rx #{build_dir['vendor/']}"
      message " done\n"
    end
  end
end
