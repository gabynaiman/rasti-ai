module Rasti
  module AI
    module Gemini
      class Client < Rasti::AI::Client

        def generate_content(contents:, model:nil, tools:[], system_instruction:nil, generation_config:nil)
          model_name = model || Rasti::AI.gemini_default_model

          body = {contents: contents}

          body[:tools] = tools unless tools.empty?
          body[:system_instruction] = system_instruction unless system_instruction.nil?
          body[:generation_config] = generation_config unless generation_config.nil?

          post "/models/#{model_name}:generateContent", body
        end

        private

        def default_api_key
          Rasti::AI.gemini_api_key
        end

        def base_url
          'https://generativelanguage.googleapis.com/v1beta'
        end

        def build_url(relative_url)
          "#{base_url}#{relative_url}?key=#{api_key}"
        end

      end
    end
  end
end
