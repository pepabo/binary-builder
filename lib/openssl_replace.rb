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
      run('wget', openssltar)
      run('tar', 'xf', filename)
      Dir.chdir("openssl-#{filebase}") do
        run("./config",
          "--prefix=/usr/local/openssl",
          "shared",
          "-fPIC"
        )
        run('make')
        run('make', 'install')
      end
    end
  end

end
