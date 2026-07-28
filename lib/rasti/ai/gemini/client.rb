module Rasti
  module AI
    module Gemini
      class Client < Rasti::AI::Client

        def generate_content(contents:, model:nil, tools:[], system_instruction:nil, generation_config:nil)
          model_name = model || default_model

          body = {contents: contents}

          body[:tools] = tools unless tools.empty?
          body[:system_instruction] = system_instruction unless system_instruction.nil?
          body[:generation_config] = generation_config unless generation_config.nil?

          post "/models/#{model_name}:generateContent", body
        end

        private

        def build_url(relative_url)
          "#{super}?key=#{api_key}"
        end

      end
    end
  end
end
