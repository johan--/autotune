require 'autotune/deployer'
require 's3deploy/deployer'

module Autotune
  module Deployers
    # Deploy to s3
    class S3 < Autotune::Deployer
      # Deploy an entire directory
      def deploy(source)
        deployer = S3deploy::Deployer.new(
          :dist_dir => source, :bucket => parts.host,
          :app_path => deploy_path, :logger => logger)
        deployer.deploy!
      end

      # Deploy a single file
      def deploy_file(source, path)
        deployer = S3deploy::Deployer.new(
          :dist_dir => source, :bucket => parts.host,
          :app_path => deploy_path, :logger => logger)
        deployer.deploy_file!(path)
      end

      # Delete stuff
      def delete!
        deployer = S3deploy::Deployer.new(
          :dist_dir => '', :bucket => parts.host,
          :app_path => deploy_path, :logger => logger)
        deployer.delete!
      end

      # Get the url to a file
      def url_for(path)
        if path =~ /\.\w{1,8}$/
          super
        else
          super + '/'
        end
      end
    end
  end
end

Autotune.register_deployer(:s3, Autotune::Deployers::S3)
