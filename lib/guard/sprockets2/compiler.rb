module Guard
  class Sprockets2::Compiler
    attr_accessor :sprockets, :assets_path, :precompile, :digest, :gz
    
    def initialize(options = {})
      if defined?(Rails) && Rails.application
        @sprockets   = Rails.application.assets
        @assets_path = File.join(Rails.public_path, Rails.application.config.assets.prefix)
        @precompile  = Rails.application.config.assets.precompile
      else
        @assets_path = File.expand_path "public/assets"
        @precompile  = [ Proc.new { |path| !%w(.js .css).include? File.extname(path) }, /(?:\/|\\|\A)application\.(css|js)$/ ]
      end
      @digest = true
      @gz     = true
      
      options.each do |key, value|
        send "#{key}=", value if respond_to? "#{key}="
      end unless options.nil?
    end
  
    def clean
      FileUtils.rm_rf @assets_path, :secure => true
    end
  
    def compile
      @sprockets.send(:expire_index!)
      success = true
      @sprockets.each_logical_path do |logical_path|
        next unless compile_path?(logical_path)

        if asset = @sprockets.find_asset(logical_path)
          success = write_asset(asset)
          break unless success
        end
      end
      success
    end

    protected
  
    def write_asset(asset)
      filename = File.join @assets_path, path_for(asset)
      FileUtils.mkdir_p File.dirname(filename)
      asset.write_to(filename)
      asset.write_to("#{filename}.gz") if @gz && filename.to_s =~ /\.(css|js)$/
      true
    rescue => e
      puts unless ENV["GUARD_ENV"] == "test"
      UI.error e.message.gsub(/^Error: /, '')
      false
    end

    def compile_path?(logical_path)
      @precompile.each do |path|
        case path
        when Regexp
          return true if path.match(logical_path)
        when Proc
          return true if path.call(logical_path)
        else
          return true if File.fnmatch(path.to_s, logical_path)
        end
      end
      false
    end

    def path_for(asset)
      @digest ? asset.digest_path : asset.logical_path
    end
  end
end