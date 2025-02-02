require 'work_dir'

module Autotune
  # setup the blueprint
  class SyncBlueprintJob < ActiveJob::Base
    queue_as :default

    lock_job :retry => 20.seconds do
      arguments.first.to_gid_param
    end

    # do the deed
    def perform(blueprint, status: nil, update: false)
      # Create a new repo object based on the blueprints working dir
      repo = WorkDir.repo(blueprint.working_dir,
                          Rails.configuration.autotune.setup_environment)

      if repo.exist?
        if update
          # Update the repo
          repo.update
        elsif blueprint.status.in?(%w(testing ready))
          # if we're not updating, bail if we have the files
          return
        elsif !update
          # we're not updating, but the blueprint is broken, so set it up
          repo.branch = blueprint.version
          repo.update
        end
      else
        # Clone the repo
        repo.clone(blueprint.repo_url)
      end

      # Setup the environment
      repo.setup_environment

      # Load the blueprint config file into the DB
      blueprint.config = repo.read BLUEPRINT_CONFIG_FILENAME
      if blueprint.config.nil?
        raise "Can't read '%s' in blueprint '%s'" % [
          BLUEPRINT_CONFIG_FILENAME, blueprint.slug]
      end

      # Track the current commit version
      blueprint.version = repo.version

      # Stash the thumbnail
      if blueprint.config['thumbnail'] && repo.exist?(blueprint.config['thumbnail'])
        deployer = Autotune.new_deployer(:media, blueprint)
        deployer.deploy_file(
          blueprint.working_dir,
          blueprint.config['thumbnail'])
      end

      # Blueprint is now ready for testing
      if status
        blueprint.status = status
      elsif blueprint.status != 'ready'
        blueprint.status = 'testing'
      end
      blueprint.save!
    rescue => exc
      # If the command failed, raise a red flag
      logger.error(exc)
      blueprint.update!(:status => 'broken')
      raise
    end
  end
end
