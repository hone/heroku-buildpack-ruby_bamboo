module RubyBamboo::Addons
  ADDONS_REPOS = {
    :hoptoad_notifier => { :url => 'git://github.com/adamwiggins/hoptoad_notifier.git' },
    :exceptional      => { :url => 'git://github.com/contrast/exceptional.git' },
    :gmail_smtp       => { :url => 'git://github.com/adamwiggins/gmail_smtp.git' },
    :quick_sendgrid   => { :url => 'git://github.com/pedro/quick_sendgrid.git' },
    :rpm              => { :url => 'git://github.com/newrelic/rpm.git', :tag => "3.0.1" },
  }

  def self.addons_dir
    Rush[File.join(File.expand_path(File.dirname(__FILE__)), "..", "vendor", "addons/")]
  end

  def self.pull_all
    puts("ruby_bamboo addons pull_all create_dir dir=#{addons_dir.full_path}")
    addons_dir.create

    ADDONS_REPOS.each do |name, addon_git|
      url = addon_git[:url]
      begin
        SystemTimer.timeout(15) do
          addon = addons_dir["#{name}/"]
          if addon.exists?
            puts("ruby_bamboo addons pull event=start name=#{name} url=#{url} dir=#{addon.full_path}")
            addon.bash "git pull origin master"
            puts("ruby_bamboo addons pull event=finish name=#{name}")
          else
            puts("ruby_bamboo addons clone event=start name=#{name} url=#{url} dir=#{addon.full_path}")
            addons_dir.bash "git clone #{url} #{name}"
            puts("ruby_bamboo addons pull event=finish name=#{name}")
          end

          addon.bash "git remote update"

          if tag = addon_git[:tag]
            puts("ruby_bamboo addons checkout event=start name=#{name} tag=#{tag}")
            addon.bash "git checkout refs/tags/#{tag}"
            puts("ruby_bamboo addons checkout event=finish name=#{name} tag=#{tag}")
          else
            puts("ruby_bamboo addons checkout event=start name=#{name} branch=master")
            addon.bash "git checkout refs/heads/master"
            puts("ruby_bamboo addons checkout event=finish name=#{name} branch=master")
          end
        end
      rescue Timeout::Error
        puts("ruby_bamboo addons event=timeout name=#{name}")
      end
    end
  end

  def incompatible_addon?(addon)
    if addon.kind_of?(Regexp)
      matches = addons.select { |a| !a.match(addon).nil? }
      if matches.size > 1 # more than 1 match? how?
        return true
      else
        addon = matches.first
      end
    end
    stacks = addons_stacks[addon] || []
    !(stacks.include?(target_stack) || stacks == [])
  end

  def install_addons
    SystemTimer.timeout(60) do
      install_hoptoad if addons.include? 'hoptoad'
      install_exceptional if addons.any? { |a| a =~ /^exceptional/ }
      install_gmail_smtp if addons.include? 'gmail_smtp'
      install_sendgrid if addons.any? { |a| a.include?('sendgrid') }
      install_new_relic if addons.any? { |a| a.include?('newrelic') }
    end
  end

  def install_hoptoad
    if language_pack != :rails
      message "-----> Not a Rails app, can't install Hoptoad plugin\n"
      return
    end

    if incompatible_addon?('hoptoad')
      message "-----> Incompatible stack, can't install Hoptoad plugin\n"
      return
    end

    message "-----> Installing Hoptoad plugin from #{ADDONS_REPOS[:hoptoad_notifier][:url]}..."

    plugins_dir = build_dir['vendor/plugins/'].create
    plugins_dir.bash "cp -R #{File.join(RubyBamboo::Addons.addons_dir.full_path, 'hoptoad_notifier')} ."
    plugins_dir['hoptoad_notifier/.git/'].destroy

    system "chmod -R go+rx #{build_dir['vendor/']}"

    message " done.\n"
  end

  def exceptional_plugin_path
    File.join(RubyBamboo::Addons.addons_dir.full_path, "exceptional")
  end

  def install_exceptional
    if language_pack != :rails
      message "-----> Not a Rails app, can't install Exceptional plugin\n"
      return
    end

    if incompatible_addon?(/^exceptional/)
      message "-----> Incompatible stack, can't install Exceptional plugin\n"
      return
    end

    message "-----> Installing Exceptional plugin from #{ADDONS_REPOS[:exceptional][:url]}..."

    plugins_dir = build_dir['vendor/plugins/'].create
    plugins_dir.bash "cp -R #{exceptional_plugin_path} ."

    exceptional = plugins_dir['exceptional/']
    exceptional['.git/'].destroy
    system "chmod -R go+rx #{build_dir['vendor/']}"

    message " done.\n"
  end

  def install_gmail_smtp
    if language_pack != :rails
      message "-----> Not a Rails app, can't install GMail SMTP add-on\n"
      return
    end

    if incompatible_addon?('gmail_smtp')
      message "-----> Incompatible stack, can't install GMail SMTP add-on\n"
      return
    end

    message "-----> Installing GMail SMTP plugin from #{ADDONS_REPOS[:gmail_smtp][:url]}..."

    plugins_dir = build_dir['vendor/plugins/'].create
    plugins_dir.bash "cp -R #{File.join(RubyBamboo::Addons.addons_dir.full_path, "gmail_smtp")} ."
    plugins_dir['gmail_smtp/.git/'].destroy

    system "chmod -R go+rx #{build_dir['vendor/']}"

    message " done.\n"
  end

  def install_sendgrid
    if language_pack != :rails
      message "-----> Not a Rails app, can't install the plugin quick_sendgrid\n"
      return
    end

    if incompatible_addon?('sendgrid')
      message "-----> Incompatible stack, can't install the plugin quick_sendgrid\n"
      return
    end

    message "-----> Installing quick_sendgrid plugin from #{ADDONS_REPOS[:quick_sendgrid][:url]}..."

    plugins_dir = build_dir['vendor/plugins/'].create
    plugins_dir.bash "cp -R #{File.join(RubyBamboo::Addons.addons_dir.full_path, "quick_sendgrid")} ."
    plugins_dir['quick_sendgrid/.git/'].destroy
    system "chmod -R go+rx #{build_dir['vendor/']}"
    message " done.\n"
  end

  def newrelic_plugin_path
    File.join(RubyBamboo::Addons.addons_dir.full_path, "rpm")
  end

  def install_new_relic
    if !env['NEW_RELIC_LICENSE_KEY'] || !env['NEW_RELIC_APPNAME']
      message "-----> New Relic is not configured. Skipping\n"
      return
    end

    message "-----> Configuring New Relic plugin..."

    config = YAML.load(Rush["#{newrelic_plugin_path}/newrelic.yml"].contents)
    rails_env = env['RACK_ENV'] || 'development'
    config[rails_env] ||= config['production'] # get default settings from production
    config[rails_env]['license_key']                       = env['NEW_RELIC_LICENSE_KEY']
    config[rails_env]['app_name']                          = env['NEW_RELIC_APPNAME'] || env['NEW_RELIC_APP_NAME']
    config[rails_env]['apdex_t']                           = env['NEW_RELIC_APDEX'].to_f if env['NEW_RELIC_APDEX']
    config[rails_env]['capture_params']                    = true if env['NEW_RELIC_CAPTURE_PARAMS']
    config[rails_env]['host']                              = env['NEW_RELIC_HOST'] if env['NEW_RELIC_HOST']
    config[rails_env]['error_collector']['enabled']        = false if env['NEW_RELIC_ERROR_COLLECTOR_ENABLED'] == 'false'
    config[rails_env]['error_collector']['capture_source'] = false if env['NEW_RELIC_ERROR_COLLECTOR_CAPTURE_SOURCE'] == 'false'
    config[rails_env]['error_collector']['ignore_errors']  = env['NEW_RELIC_ERROR_COLLECTOR_IGNORE_ERRORS'] if env.key?('NEW_RELIC_ERROR_COLLECTOR_IGNORE_ERRORS')
    build_dir['config/'].create
    build_dir['config/newrelic.yml'].write config.to_yaml
    system "chmod -R go+rx #{build_dir['config/newrelic.yml']}"
    message " done.\n"

    if language_pack == :rails and !incompatible_addon?('newrelic')
      if build_dir['vendor/plugins/rpm/'].exists?
        message "       New Relic plugin already installed, skipping installation.\n"
      elsif installed_gems.include?("newrelic_rpm")
        message "       New Relic gem already installed, skipping plugin installation.\n"
      else
        message "       Installing the New Relic plugin..."
        plugins_dir = build_dir['vendor/plugins/'].create
        plugins_dir.bash "cp -R #{newrelic_plugin_path} ."
        plugins_dir['rpm/.git/'].destroy
        system "chmod -R go+rx #{build_dir['vendor/']}"
        message " done.\n"
      end
    elsif incompatible_addon?('newrelic')
      message "       Incompatible stack, not installing New Relic plugin.\n"
    else
      message "       Not a Rails app, can't install New Relic plugin.\n"
    end
  end
end
