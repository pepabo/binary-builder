# encoding: utf-8
require_relative 'php_common_recipes'
require_relative 'php7_recipe'

class PhpMeal
  attr_reader :name, :version

  def initialize(name, version, options)
    @name    = name
    @version = version
    version_parts = version.split('.')
    @major_version = version_parts[0]
    @minor_version = version_parts[1]
    @options = options
    @native_modules = []
    @extensions = []

    create_native_module_recipes
    create_extension_recipes

    (@native_modules + @extensions).each do |recipe|
      recipe.instance_variable_set('@php_path', php_recipe.path)
      recipe.instance_variable_set('@php_source', "#{php_recipe.send(:tmp_path)}/php-#{@version}")

      if recipe.is_a? FakePeclRecipe
        recipe.instance_variable_set('@version', @version)
        recipe.instance_variable_set('@files', [{url: recipe.url, md5: nil}])
      end
    end
  end

  def cook
    system <<-eof
      apt-get -qqy update
      apt-get -qqy upgrade
      apt-get -qqy install #{apt_packages}
      #{install_libuv}
      #{install_idnkit}
      #{install_argon2}
      #{symlink_commands}
    eof

    if OraclePeclRecipe.oracle_sdk?
      Dir.chdir('/oracle') do
        system "ln -s libclntsh.so.* libclntsh.so"
      end
    end
    php_recipe.cook

    php_recipe.activate

    # native libraries
    @native_modules.each do |recipe|
      recipe.cook
    end

    # php extensions
    @extensions.each do |recipe|
      recipe.cook if should_cook?(recipe)
    end
  end

  def url
    php_recipe.url
  end

  def archive_files
    php_recipe.archive_files
  end

  def archive_path_name
    php_recipe.archive_path_name
  end

  def archive_filename
    php_recipe.archive_filename
  end

  def setup_tar
    php_recipe.setup_tar
    if OraclePeclRecipe.oracle_sdk?
      @extensions.detect{|r| r.name=='oci8'}.setup_tar
      @extensions.detect{|r| r.name=='pdo_oci'}.setup_tar
    end
    @extensions.detect{|r| r.name=='odbc'}&.setup_tar
    @extensions.detect{|r| r.name=='pdo_odbc'}&.setup_tar
    @extensions.detect{|r| r.name=='sodium'}&.setup_tar
  end

  private

  def create_native_module_recipes
    return unless @options[:php_extensions_file]
    php_extensions_hash = YAML.load_file(@options[:php_extensions_file])

    php_extensions_hash['native_modules'].each do |hash|
      klass = Kernel.const_get(hash['klass'])

      @native_modules << klass.new(
        hash['name'],
        hash['version'],
        md5: hash['md5']
      )
    end
  end

  def create_extension_recipes
    return unless @options[:php_extensions_file]
    php_extensions_hash = YAML.load_file(@options[:php_extensions_file])

    php_extensions_hash['extensions'].each do |hash|
      next if ['sqlsrv', 'pdo_sqlsrv'].include?(hash['name']) && ENV['STACK'] != 'cflinuxfs3'

      klass = Kernel.const_get(hash['klass'])

      @extensions << klass.new(
        hash['name'],
        hash['version'],
        md5: hash['md5']
      )
    end

    @extensions.each do |recipe|
      case recipe.name
      when 'amqp'
        recipe.instance_variable_set('@rabbitmq_path', @native_modules.detect{|r| r.name=='rabbitmq'}.work_path)
      when 'memcached'
        recipe.instance_variable_set('@libmemcached_path', @native_modules.detect{|r| r.name=='libmemcached'}.path)
      when 'lua'
        recipe.instance_variable_set('@lua_path', @native_modules.detect{|r| r.name=='lua'}.path)
      when 'phalcon'
        recipe.instance_variable_set('@php_version', "php#{@major_version}")
      when 'phpiredis'
        recipe.instance_variable_set('@hiredis_path', @native_modules.detect{|r| r.name=='hiredis'}.path)
      when 'odbc'
        recipe.instance_variable_set('@unixodbc_path', @native_modules.detect{|r| r.name=='unixodbc'}.path)
      when 'pdo_odbc'
        recipe.instance_variable_set('@unixodbc_path', @native_modules.detect{|r| r.name=='unixodbc'}.path)
      when 'sodium'
        recipe.instance_variable_set('@libsodium_path', @native_modules.detect{|r| r.name=='libsodium'}.path)
      end
    end
  end

  def apt_packages
    packages = php_common_apt_packages
    packages += php7_apt_packages
    if @version =~ /^5.3/
      packages << "libmysqlclient-dev"
    end
    if ENV['STACK'] == 'cflinuxfs2'
      packages += php7_cflinuxfs2_apt_packages
    elsif ENV['STACK'] == 'cflinuxfs3'
      packages += php7_cflinuxfs3_apt_packages
    end
    return packages.join(" ")
  end

  def php7_apt_packages
    %w(libedit-dev)
  end

  def php7_cflinuxfs3_apt_packages
    %w(libkrb5-dev libssl-dev libcurl4-openssl-dev unixodbc-dev libmaxminddb-dev)
  end

  def php7_cflinuxfs2_apt_packages
    %w(libssl-dev libcurl4-openssl-dev)
  end

  def php_common_apt_packages
    %w(libaspell-dev
      libc-client2007e-dev
      libexpat1-dev
      libgdbm-dev
      libgmp-dev
      libgpgme11-dev
      libjpeg-dev
      libldap2-dev
      libmcrypt-dev
      libpng-dev
      libpspell-dev
      libsasl2-dev
      libsnmp-dev
      libsqlite3-dev
      libtool
      libxml2-dev
      libzip-dev
      libzookeeper-mt-dev
      snmp-mibs-downloader
      automake
      libgeoip-dev
      libtidy-dev
      libenchant-dev
      firebird-dev
      librecode-dev)
  end

  def install_libuv
    %q((
       cd /tmp
       wget http://dist.libuv.org/dist/v1.12.0/libuv-v1.12.0.tar.gz
       tar zxf libuv-v1.12.0.tar.gz
       cd libuv-v1.12.0
       sh autogen.sh
       ./configure
       make install
       )
    )
  end

  def install_idnkit
    %q((
        cd /usr/local/src
        curl -O -L http://www.nic.ad.jp/ja/idn/idnkit/download/sources/idnkit-1.0-src.tar.gz
        tar zxf idnkit-1.0-src.tar.gz
        cd idnkit-1.0-src
        ./configure
        make
        make install
       )
    )
  end

  def install_argon2
    return '' if ENV['STACK'] == 'cflinuxfs3' || (@major_version == '7' && @minor_version.to_i < 2)
    %q((
      cd /tmp
      curl -L -O https://github.com/P-H-C/phc-winner-argon2/archive/20171227.tar.gz
      tar zxf 20171227.tar.gz
      cd phc-winner-argon2-20171227
      make
      make test
      make install PREFIX=/usr/local
      )
    )
  end

  def symlink_commands
    php7_symlinks.join("\n")
  end

  def php7_symlinks
    php_common_symlinks +
        ["sudo ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl"] # This is required for php 7.1.x on cflinuxfs3
  end

  def php_common_symlinks
    ["sudo ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl", # This is required for php 7.1.x on cflinuxfs3
      "sudo ln -fs /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h",
      "sudo ln -fs /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so",
      "sudo ln -fs /usr/lib/x86_64-linux-gnu/libldap_r.so /usr/lib/libldap_r.so"]
  end


  def should_cook?(recipe)
    case recipe.name
    when 'phalcon'
       PhalconRecipe.build_phalcon?(version)
    when 'ioncube'
       IonCubeRecipe.build_ioncube?(version)
    when 'oci8', 'pdo_oci'
       OraclePeclRecipe.oracle_sdk?
    when 'maxmind', 'libmaxmind'
       ENV['STACK'] == 'cflinuxfs3' ? true : false
    else
       true
    end
  end

  def files_hashs
    native_module_hashes = @native_modules.map do |recipe|
      recipe.send(:files_hashs)
    end.flatten

    extension_hashes = @extensions.map do |recipe|
      recipe.send(:files_hashs) if should_cook?(recipe)
    end.flatten.compact

    extension_hashes + native_module_hashes
  end

  def php_recipe
    php_recipe_options = {}

    hiredis_recipe = @native_modules.detect{|r| r.name=='hiredis'}
    libmemcached_recipe = @native_modules.detect{|r| r.name=='libmemcached'}
    ioncube_recipe = @extensions.detect{|r| r.name=='ioncube'}

    php_recipe_options[:hiredis_path] = hiredis_recipe.path unless hiredis_recipe.nil?
    php_recipe_options[:libmemcached_path] = libmemcached_recipe.path unless libmemcached_recipe.nil?
    php_recipe_options[:ioncube_path] = ioncube_recipe.path unless ioncube_recipe.nil?

    php_recipe_options.merge(DetermineChecksum.new(@options).to_h)

    @php_recipe ||= Php7Recipe.new(@name, @version, php_recipe_options)
  end
end
