require_relative '../recipe/base'

class OpenSSLReplace

  def self.run(*args)
    system({'DEBIAN_FRONTEND' => 'noninteractive'}, *args)
    raise "Could not run #{args}" unless $?.success?
  end

  def self.replace_openssl(version=nil)
    filebase = version || 'OpenSSL_1_1_0g'
    filename = "#{filebase}.tar.gz"
    openssltar = "https://github.com/openssl/openssl/archive/#{filename}"

    Dir.mktmpdir do |dir|
      unless File.exists?(filename)
        run('wget', openssltar)
        run('tar', 'xf', filename)
      end
      Dir.chdir("openssl-#{filebase}") do
        run("./config",
          "--prefix=/usr/local/openssl",
          "shared",
          "-fPIC"
        )
        run('make -j 4')
        run('make', 'install')
      end
    end
  end

end
