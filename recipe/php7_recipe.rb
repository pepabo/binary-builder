# encoding: utf-8
require_relative 'php_common_recipes'
require_relative '../lib/openssl_replace'

class Php7Recipe < BaseRecipe
  def initialize(name, version, options = {})
    super name, version, options
    # override openssl in container
    OpenSSLReplace.replace_openssl("OpenSSL_1_0_2s") if major_version =~ /^5/
  end

  def configure_options
    [
      '--disable-static',
      '--enable-shared',
      '--enable-ftp=shared',
      '--enable-sockets=shared',
      '--enable-soap=shared',
      '--enable-fileinfo=shared',
      '--enable-bcmath',
      '--enable-calendar',
      '--enable-intl',
      '--with-kerberos',
      '--enable-zip=shared',
      '--with-bz2=shared',
      '--with-curl=shared',
      '--enable-dba=shared',
      "--with-password-argon2=#{ENV['STACK'] == 'cflinuxfs3' ? '/usr/lib/x86_64-linux-gnu' : '/usr/local'}",
      '--with-cdb',
      '--with-gdbm',
      '--with-mcrypt=shared',
      '--with-mysqli=shared',
      '--enable-pdo=shared',
      '--with-pdo-sqlite=shared,/usr',
      '--with-pdo-mysql=shared,mysqlnd',
      '--with-gd=shared',
      '--with-jpeg-dir=/usr',
      '--with-freetype-dir=/usr',
      '--enable-gd-native-ttf',
      '--with-pdo-pgsql=shared',
      '--with-pgsql=shared',
      '--with-pspell=shared',
      '--with-gettext=shared',
      '--with-gmp=shared',
      '--with-imap=shared',
      '--with-imap-ssl=shared',
      '--with-ldap=shared',
      '--with-ldap-sasl',
      '--with-zlib=shared',
      "#{ENV['STACK'] == 'cflinuxfs3' ? '--with-libzip=/usr/local/lib' : ''}",
      '--with-xsl=shared',
      '--with-snmp=shared',
      '--enable-mbstring=shared',
      '--enable-mbregex',
      '--enable-exif=shared',
      '--enable-fpm',
      '--enable-pcntl=shared',
      '--enable-sysvsem=shared',
      '--enable-sysvshm=shared',
      '--enable-sysvmsg=shared',
      '--enable-shmop=shared',
      major_version =~ /^5/ ? '--with-openssl=/usr/local/openssl/' : '--with-openssl=shared',
      "#{ENV['STACK'] == 'cflinuxfs3' ? '--with-pdo_sqlsrv=shared' : ''}"
    ]
  end

  def url
    "https://php.net/distributions/php-#{version}.tar.gz"
  end

  def archive_files
    ["#{port_path}/*"]
  end

  def archive_path_name
    'php'
  end

  def configure
    return if configured?

    md5_file = File.join(tmp_path, 'configure.md5')
    digest   = Digest::MD5.hexdigest(computed_options.to_s)
    File.open(md5_file, 'w') { |f| f.write digest }

    # LIBS=-lz enables using zlib when configuring
    execute('configure', ['bash', '-c', "LIBS=-lz ./configure #{computed_options.join ' '}"])
  end

  def major_version
    @major_version ||= version.match(/^(\d+\.\d+)/)[1]
  end

  def zts_path
    Dir["#{path}/lib/php/extensions/no-debug-non-zts-*"].first
  end

  def setup_tar
    lib_dir   = `lsb_release -r | awk '{print $2}'`.strip == '18.04' ?
      '/usr/lib/x86_64-linux-gnu' :
      '/usr/lib'
    argon_dir = `lsb_release -r | awk '{print $2}'`.strip == '18.04' ?
      '/usr/lib/x86_64-linux-gnu' :
      '/usr/local/lib'

    system <<-eof
      cp -a /usr/local/lib/x86_64-linux-gnu/librabbitmq.so* #{path}/lib/
      cp -a #{@hiredis_path}/lib/libhiredis.so* #{path}/lib/
      cp -a /usr/lib/libc-client.so* #{path}/lib/
      cp -a /usr/lib/libmcrypt.so* #{path}/lib
      cp -a #{lib_dir}/libaspell.so* #{path}/lib
      cp -a #{lib_dir}/libpspell.so* #{path}/lib
      cp -a #{@libmemcached_path}/lib/libmemcached.so* #{path}/lib/
      cp -a /usr/local/lib/x86_64-linux-gnu/libcassandra.so* #{path}/lib
      cp -a /usr/local/lib/libuv.so* #{path}/lib
      cp -a #{argon_dir}/libargon2.so* #{path}/lib
      cp -a /usr/lib/librdkafka.so* #{path}/lib
      cp -a /usr/lib/x86_64-linux-gnu/libzip.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libGeoIP.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libgpgme.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libassuan.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libgpg-error.so* #{path}/lib/
      cp -a /usr/lib/libtidy*.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libenchant.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libfbclient.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/librecode.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libtommath.so* #{path}/lib/
      cp -a /usr/lib/x86_64-linux-gnu/libmaxminddb.so* #{path}/lib/
    eof

    if IonCubeRecipe.build_ioncube?(version)
      system "cp #{@ioncube_path}/ioncube/ioncube_loader_lin_#{major_version}.so #{zts_path}/ioncube.so"
    end

    system <<-eof
      # Remove unused files
      rm "#{path}/etc/php-fpm.conf.default"
      rm -rf "#{path}/include"
      rm -rf "#{path}/php"
      rm -rf "#{path}/lib/php/build"
      rm "#{path}/bin/php-cgi"
      find "#{path}/lib/php/extensions" -name "*.a" -type f -delete
    eof
  end
end
