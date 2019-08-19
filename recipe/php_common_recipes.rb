# encoding: utf-8
require_relative 'base'
require_relative '../lib/geoip_downloader'
require 'uri'

class PeclRecipe < BaseRecipe
  def url
    "http://pecl.php.net/get/#{name}-#{version}.tgz"
  end

  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config"
    ]
  end

  def configure
    return if configured?

    md5_file = File.join(tmp_path, 'configure.md5')
    digest   = Digest::MD5.hexdigest(computed_options.to_s)
    File.open(md5_file, 'w') { |f| f.write digest }

    execute('configure', 'phpize')
    execute('configure', %w(sh configure) + computed_options)
  end
end

class AmqpPeclRecipe < PeclRecipe
  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config"
    ]
  end
end

class LibMaxMindRecipe < BaseRecipe
  def url
    "https://github.com/maxmind/libmaxminddb/releases/download/#{version}/libmaxminddb-#{version}.tar.gz"
  end
end

class MaxMindRecipe < BaseRecipe
  def url
    "https://github.com/maxmind/MaxMind-DB-Reader-php/archive/v#{version}.tar.gz"
  end

  def work_path
    File.join(tmp_path, "MaxMind-DB-Reader-php-#{version}", 'ext')
  end

  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config"
    ]
  end

  def configure
    return if configured?

    execute('configure', %w(bash -c phpize))
    execute('configure', %w(sh configure) + computed_options)
  end
end

class GeoipRecipe < PeclRecipe
    def cook
        super
        system <<-eof
          cd #{@php_path}
          mkdir -p geoipdb/bin
          mkdir -p geoipdb/lib
          mkdir -p geoipdb/dbs
          cp #{File.expand_path(File.join(File.dirname(__FILE__), '..'))}/bin/download_geoip_db.rb ./geoipdb/bin/
          cp #{File.expand_path(File.join(File.dirname(__FILE__), '..'))}/lib/geoip_downloader.rb ./geoipdb/lib/
        eof
        if File.exist? "BUNDLE_GEOIP_LITE" then
            products = "GeoLite-Legacy-IPv6-City GeoLite-Legacy-IPv6-Country 506 517 533"
            updater = MaxMindGeoIpUpdater.new(MaxMindGeoIpUpdater.FREE_USER, MaxMindGeoIpUpdater.FREE_LICENSE, File.join(@php_path, 'geoipdb', 'dbs'))
            products.split(" ").each do |product|
                updater.download_product(product)
            end
        end
    end
end

class HiredisRecipe < BaseRecipe
  def url
    "https://github.com/redis/hiredis/archive/v#{version}.tar.gz"
  end

  def configure
  end

  def install
    return if installed?

    execute('install', ['bash', '-c', "LIBRARY_PATH=lib PREFIX='#{path}' #{make_cmd} install"])
  end
end

class LibSodiumRecipe < BaseRecipe
  def url
    "https://download.libsodium.org/libsodium/releases/libsodium-#{version}.tar.gz"
  end
end

class IonCubeRecipe < BaseRecipe
  def url
    "http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64_#{version}.tar.gz"
  end

  def configure; end

  def compile; end

  def install; end

  def self.build_ioncube?(php_version)
    true
  end

  def path
    tmp_path
  end
end

class LibmemcachedRecipe < BaseRecipe
  def url
    "https://launchpad.net/libmemcached/1.0/#{version}/+download/libmemcached-#{version}.tar.gz"
  end

  def configure
    return if configured?

    cache_file = File.join(tmp_path, 'configure.options_cache')
    File.open(cache_file, "w") { |f| f.write computed_options.to_s }

    ENV['CXXFLAGS'] = '-fpermissive'
    execute('configure', %w(./configure) + computed_options)
  end
end

# We need to compile from source until Ubuntu packages version 2.3.0+
#  The unixODBC library version changed from 1 to 2 at this point, so
#  newer ODBC drivers won't work with the older library.
class UnixOdbcRecipe < BaseRecipe
  def url
    "http://www.unixodbc.org/unixODBC-#{version}.tar.gz"
  end
end

class LibRdKafkaRecipe < BaseRecipe
  def url
    "https://github.com/edenhill/librdkafka/archive/v#{version}.tar.gz"
  end

  def work_path
    File.join(tmp_path, "librdkafka-#{version}")
  end

  def configure_prefix
    '--prefix=/usr'
  end

  def configure
    return if configured?

    md5_file = File.join(tmp_path, 'configure.md5')
    digest   = Digest::MD5.hexdigest(computed_options.to_s)
    File.open(md5_file, 'w') { |f| f.write digest }

    execute('configure', %w(bash ./configure) + computed_options)
  end
end

class CassandraCppDriverRecipe < BaseRecipe
  def url
    "https://github.com/datastax/cpp-driver/archive/#{version}.tar.gz"
  end

  def configure
  end

  def compile
    execute('compile', ['bash', '-c', 'mkdir -p build && cd build && cmake .. && make'])
  end

  def install
    execute('install', ['bash', '-c', 'cd build && make install'])
  end
end

class LuaPeclRecipe < PeclRecipe
  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config",
      "--with-lua=#{@lua_path}"
    ]
  end
end

class LuaRecipe < BaseRecipe
  def url
    "http://www.lua.org/ftp/lua-#{version}.tar.gz"
  end

  def configure
  end

  def compile
    execute('compile', ['bash', '-c', "#{make_cmd} linux MYCFLAGS=-fPIC"])
  end

  def install
    return if installed?

    execute('install', ['bash', '-c', "#{make_cmd} install INSTALL_TOP=#{path}"])
  end
end

class MemcachedPeclRecipe < PeclRecipe
  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config",
      "--with-libmemcached-dir=#{@libmemcached_path}",
      '--enable-memcached-sasl',
      '--enable-memcached-msgpack',
      '--enable-memcached-igbinary',
      '--enable-memcached-json'
    ]
  end
end

class FakePeclRecipe < PeclRecipe
  def url
    "file://#{@php_source}/ext/#{name}-#{version}.tar.gz"
  end

  def download
    # this copys an extension folder out of the PHP source director (i.e. `ext/<name>`)
    # it pretends to download it by making a zip of the extension files
    # that way the rest of the PeclRecipe works normally
    files_hashs.each do |file|
      path = URI(file[:url]).path.rpartition('-')[0] # only need path before the `-`, see url above
      system <<-eof
        echo 'tar czf "#{file[:local_path]}" -C "#{File.dirname(path)}" "#{File.basename(path)}"'
        tar czf "#{file[:local_path]}" -C "#{File.dirname(path)}" "#{File.basename(path)}"
      eof
    end
  end
end

class OdbcRecipe < FakePeclRecipe
  def configure_options
    [
      "--with-unixODBC=shared,#{@unixodbc_path}"
    ]
  end

  def patch
    system <<-eof
      cd #{work_path}
      echo 'AC_DEFUN([PHP_ALWAYS_SHARED],[])dnl' > temp.m4
      echo >> temp.m4
      cat config.m4 >> temp.m4
      mv temp.m4 config.m4
    eof
  end

  def setup_tar
    system <<-eof
      cp -a #{@unixodbc_path}/lib/libodbc.so* #{@php_path}/lib/
      cp -a #{@unixodbc_path}/lib/libodbcinst.so* #{@php_path}/lib/
    eof
  end
end

class SodiumRecipe < FakePeclRecipe
  def configure_options
    ENV['LDFLAGS'] = "-L#{@libsodium_path}/lib"
    [
      "--with-php-config=#{@php_path}/bin/php-config",
      "--with-sodium=#{@libsodium_path}"
    ]
  end

  def setup_tar
    system <<-eof
      cp -a #{@libsodium_path}/lib/libsodium.so* #{@php_path}/lib/
    eof
  end
end

class PdoOdbcRecipe < FakePeclRecipe
  def configure_options
    [
      "--with-pdo-odbc=unixODBC,#{@unixodbc_path}"
    ]
  end

  def setup_tar
    system <<-eof
      cp -a #{@unixodbc_path}/lib/libodbc.so* #{@php_path}/lib/
      cp -a #{@unixodbc_path}/lib/libodbcinst.so* #{@php_path}/lib/
    eof
  end

end

class OraclePdoRecipe < FakePeclRecipe
  def configure_options
    [
      "--with-pdo-oci=shared,instantclient,/oracle,#{OraclePdoRecipe.oracle_version}"
    ]
  end

  def self.oracle_version
    Dir["/oracle/*"].select {|i| i.match(/libclntsh\.so\./) }.map {|i| i.sub(/.*libclntsh\.so\./, '')}.first
  end

  def setup_tar
    system <<-eof
      cp -an /oracle/libclntshcore.so.12.1 #{@php_path}/lib
      cp -an /oracle/libclntsh.so #{@php_path}/lib
      cp -an /oracle/libclntsh.so.12.1 #{@php_path}/lib
      cp -an /oracle/libipc1.so #{@php_path}/lib
      cp -an /oracle/libmql1.so #{@php_path}/lib
      cp -an /oracle/libnnz12.so #{@php_path}/lib
      cp -an /oracle/libociicus.so #{@php_path}/lib
      cp -an /oracle/libons.so #{@php_path}/lib
    eof
  end
end

class OraclePeclRecipe < PeclRecipe
  def configure_options
    [
      "--with-oci8=shared,instantclient,/oracle"
    ]
  end

  def self.oracle_sdk?
    File.directory?('/oracle')
  end

  def setup_tar
    system <<-eof
      cp -an /oracle/libclntshcore.so.12.1 #{@php_path}/lib
      cp -an /oracle/libclntsh.so #{@php_path}/lib
      cp -an /oracle/libclntsh.so.12.1 #{@php_path}/lib
      cp -an /oracle/libipc1.so #{@php_path}/lib
      cp -an /oracle/libmql1.so #{@php_path}/lib
      cp -an /oracle/libnnz12.so #{@php_path}/lib
      cp -an /oracle/libociicus.so #{@php_path}/lib
      cp -an /oracle/libons.so #{@php_path}/lib
    eof
  end
end

class PhalconRecipe < PeclRecipe
  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config",
      '--enable-phalcon'
    ]
  end

  def work_path
    "#{super}/build/#{@php_version}/64bits"
  end

  def url
    "https://github.com/phalcon/cphalcon/archive/v#{version}.tar.gz"
  end

  def self.build_phalcon?(php_version)
    true
  end
end

class PHPIRedisRecipe < PeclRecipe
  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config",
      '--enable-phpiredis',
      "--with-hiredis-dir=#{@hiredis_path}"
    ]
  end

  def url
    "https://github.com/nrk/phpiredis/archive/v#{version}.tar.gz"
  end
end

class RedisPeclRecipe < PeclRecipe
  def configure_options
    [
      "--with-php-config=#{@php_path}/bin/php-config",
      "--enable-redis-igbinary",
      "--enable-redis-lzf",
      "--with-liblzf=no"
    ]
  end
end

class PHPProtobufPeclRecipe < PeclRecipe
  def url
    "https://github.com/allegro/php-protobuf/archive/v#{version}.tar.gz"
  end
end

class TidewaysXhprofRecipe < PeclRecipe
  def url
    "https://github.com/tideways/php-xhprof-extension/archive/v#{version}.tar.gz"
  end
end

class RabbitMQRecipe < BaseRecipe
  def url
    "https://github.com/alanxz/rabbitmq-c/archive/v#{version}.tar.gz"
  end

  def work_path
    File.join(tmp_path, "rabbitmq-c-#{@version}")
  end

  def configure
  end

  def compile
    execute('compile', ['bash', '-c', 'cmake .'])
    execute('compile', ['bash', '-c', 'cmake --build .'])
    execute('compile', ['bash', '-c', 'cmake -DCMAKE_INSTALL_PREFIX=/usr/local .'])
    execute('compile', ['bash', '-c', 'cmake --build . --target install'])
  end
end

class SnmpRecipe
  attr_reader :name, :version

  def initialize(name, version, options)
    @name = name
    @version = version
    @options = options
  end

  def files_hashs
    []
  end

  def cook
    system <<-eof
      cd #{@php_path}
      mkdir -p mibs
      cp "/usr/lib/x86_64-linux-gnu/libnetsnmp.so.30" lib/
      # copy mibs that are packaged freely
      cp -r /usr/share/snmp/mibs/* mibs
      # copy mibs downloader & smistrip, will download un-free mibs
      cp /usr/bin/download-mibs bin
      cp /usr/bin/smistrip bin
      sed -i "s|^CONFDIR=/etc/snmp-mibs-downloader|CONFDIR=\$HOME/php/mibs/conf|" bin/download-mibs
      sed -i "s|^SMISTRIP=/usr/bin/smistrip|SMISTRIP=\$HOME/php/bin/smistrip|" bin/download-mibs
      # copy mibs download config
      cp -R /etc/snmp-mibs-downloader mibs/conf
      sed -i "s|^DIR=/usr/share/doc|DIR=\$HOME/php/mibs/originals|" mibs/conf/iana.conf
      sed -i "s|^DEST=iana|DEST=|" mibs/conf/iana.conf
      sed -i "s|^DIR=/usr/share/doc|DIR=\$HOME/php/mibs/originals|" mibs/conf/ianarfc.conf
      sed -i "s|^DEST=iana|DEST=|" mibs/conf/ianarfc.conf
      sed -i "s|^DIR=/usr/share/doc|DIR=\$HOME/php/mibs/originals|" mibs/conf/rfc.conf
      sed -i "s|^DEST=ietf|DEST=|" mibs/conf/rfc.conf
      sed -i "s|^BASEDIR=/var/lib/mibs|BASEDIR=\$HOME/php/mibs|" mibs/conf/snmp-mibs-downloader.conf
      # copy data files
      mkdir mibs/originals
      cp -R /usr/share/doc/mibiana mibs/originals
      cp -R /usr/share/doc/mibrfcs mibs/originals
    eof
  end
end

class SuhosinPeclRecipe < PeclRecipe
  def url
    "https://github.com/sektioneins/suhosin/archive/#{version}.tar.gz"
  end
end

class TwigPeclRecipe < PeclRecipe
  def url
    "https://github.com/twigphp/Twig/archive/v#{version}.tar.gz"
  end

  def work_path
    "#{super}/ext/twig"
  end
end

class XcachePeclRecipe < PeclRecipe
  def url
    "http://xcache.lighttpd.net/pub/Releases/#{version}/xcache-#{version}.tar.gz"
  end
end

class XhprofPeclRecipe < PeclRecipe
  def url
    "https://github.com/phacility/xhprof/archive/#{version}.tar.gz"
  end

  def work_path
    "#{super}/extension"
  end
end

class IDNKitRecipe < PeclRecipe
  def url
    "http://www.sera.desuyo.net/idnkit/php-idnkit-#{version}.tar.gz"
  end

  def patch
    patch_content = <<~EOS
--- xxx/idnkit.c
+++ yyy/idnkit.c
@@ -36,7 +36,11 @@ static int le_idnkit;
  *
  * Every user visible function must have an entry in idnkit_functions[].
  */
+#if ZEND_MODULE_API_NO >= 20100525
+zend_function_entry idnkit_functions[] = {
+#else
 function_entry idnkit_functions[] = {
+#endif
 	PHP_FE(idnkit_decodename,	NULL)
 	PHP_FE(idnkit_encodename,	NULL)
 	PHP_FE(idnkit_errno,		NULL)
@@ -104,7 +108,7 @@ PHP_MINIT_FUNCTION(idnkit)
 	idn_nameinit(1);

 	/* get idnkit version */
-	REGISTER_STRING_CONSTANT("IDNKIT_VERSION", (char*)idn_version_getstring(), CONST_CS | CONST_PERSISTENT);
+	REGISTER_STRING_CONSTANT("IDNKIT_VERSION", "1.0", CONST_CS | CONST_PERSISTENT);

 	/* idnkit actions */
 	REGISTER_LONG_CONSTANT("IDNKIT_DELIMMAP",		IDN_DELIMMAP,		CONST_CS | CONST_PERSISTENT);
    EOS
    File.open("#{work_path}/php-idnkit.patch","w") do |f|
      f.puts(patch_content)
    end

    system <<-eof
      cd #{work_path}
      patch -lsp1 --dry-run < #{work_path}/php-idnkit.patch >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        patch -lsp1 < #{work_path}/php-idnkit.patch
      fi
    eof
  end

  def work_path
    File.join(tmp_path, "idnkit")
  end

  def configure
    return if configured?

    execute('configure', %w(bash -c phpize))
    execute('configure', %w(sh configure) + computed_options)
  end
end
