require 'yaml'
require 'procodile/error'
require 'procodile/process'

module Procodile
  class Config

    COLORS = [35, 31, 36, 32, 33, 34]

    attr_reader :root

    def initialize(root)
      @root = root
      unless File.exist?(procfile_path)
        raise Error, "Procfile not found at #{procfile_path}"
      end

      FileUtils.mkdir_p(pid_root)
      FileUtils.mkdir_p(log_root)
    end

    def reload
      @process_list = nil
      @options = nil
      @process_options = nil

      # Update the commands for processes
      process_list.each do |name, command|
        if process = @processes[name]
          if process.command != command
            process.command = command
            Procodile.log nil, 'system', "#{name} command has changed. Updated."
          end

          if process_options[name].is_a?(Hash)
            process.options = process_options[name]
          else
            process.options = {}
          end

        else
          Procodile.log nil, 'system', "#{name} is no longer in the Procfile. Removing it."
          @process.delete(name)
        end
      end

    end

    def app_name
      options['app_name'] || 'Procodile'
    end

    def processes
      @processes ||= process_list.each_with_index.each_with_object({}) do |((name, command), index), hash|
        hash[name] = Process.new(self, name, command, process_options[name] || {})
        hash[name].log_color = COLORS[index.divmod(COLORS.size)[1]]
      end
    end

    def process_list
      @process_list ||= YAML.load_file(procfile_path)
    end

    def options
      @options ||= File.exist?(options_path) ? YAML.load_file(options_path) : {}
    end

    def process_options
      @process_options ||= options['processes'] || {}
    end

    def pid_root
      File.expand_path(options['pid_root'] || 'pids', @root)
    end

    def log_root
      File.expand_path(options['log_root'] || 'log', @root)
    end

    private

    def procfile_path
      File.join(@root, 'Procfile')
    end

    def options_path
      File.join(@root, 'Procfile.options')
    end

  end
end