module Support
  module Helpers
    module Resources

      RESOURCES_PATH = File.expand_path('../../../resources', __FILE__)

      def resource_path(relative_path)
        File.join RESOURCES_PATH, relative_path
      end

      def read_resource(relative_path, variables={})
        filename = resource_path relative_path
        content = File.read filename
        erb content, variables
      end

    end
  end
end