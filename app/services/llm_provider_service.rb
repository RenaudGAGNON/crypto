class LlmProviderService
  class BaseProvider
    def initialize(api_key)
      @api_key = api_key
    end

    def analyze_chart(chart_data)
      raise NotImplementedError, "Subclasses must implement analyze_chart"
    end

    protected

    def extract_section(content, section_name)
      content.match(/#{section_name}[:\s]+(.*?)(?=\n\n|\z)/i)&.[](1)&.strip
    end

    def format_base_prompt
      <<~PROMPT
        En tant qu'expert en analyse technique de trading, analysez les données de graphique suivantes et fournissez une réponse structurée avec :
        1. Score de confiance (0-100) : [VOTRE_SCORE]
        2. Force de la tendance : [ANALYSE]
        3. Support et résistance : [NIVEAUX]
        4. Reconnaissance des patterns : [PATTERNS]
        5. Analyse du volume : [ANALYSE]
        6. Évaluation du risque : [RISQUE]
        7. Recommandations : [RECOMMANDATIONS]

        Format de réponse attendu :
        Score de confiance: [NOMBRE]
        Force de la tendance: [TEXTE]
        Support et résistance: [TEXTE]
        Reconnaissance des patterns: [TEXTE]
        Analyse du volume: [TEXTE]
        Évaluation du risque: [TEXTE]
        Recommandations: [TEXTE]
      PROMPT
    end
  end

  class ChatGptProvider < BaseProvider
    def analyze_chart(chart_data)
      response = HTTParty.post(
        "https://api.openai.com/v1/chat/completions",
        headers: {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json"
        },
        body: {
          model: "gpt-4-turbo-preview",
          messages: [
            {
              role: "system",
              content: "Vous êtes un expert en analyse technique de trading. Votre analyse doit être précise, factuelle et basée uniquement sur les données fournies."
            },
            {
              role: "user",
              content: format_prompt(chart_data)
            }
          ],
          temperature: 0.3,
          max_tokens: 1000
        }.to_json
      )

      return nil unless response.success?
      process_response(JSON.parse(response.body))
    end

    private

    def format_prompt(chart_data)
      format_base_prompt + "\n\nDonnées du graphique :\n#{chart_data.to_json}"
    end

    def process_response(response)
      content = response.dig("choices", 0, "message", "content")
      return nil unless content

      {
        confidence_score: extract_confidence_score(content),
        analysis: extract_analysis(content),
        raw_response: content
      }
    end

    def extract_confidence_score(content)
      content.match(/score de confiance[:\s]+(\d+)/i)&.[](1)&.to_i || 0
    end

    def extract_analysis(content)
      {
        trend_strength: extract_section(content, "force de la tendance"),
        support_resistance: extract_section(content, "support et résistance"),
        pattern_recognition: extract_section(content, "reconnaissance des patterns"),
        volume_analysis: extract_section(content, "analyse du volume"),
        risk_assessment: extract_section(content, "évaluation du risque"),
        recommendations: extract_section(content, "recommandations")
      }
    end
  end

  class ClaudeProvider < BaseProvider
    MODELS = {
      opus: "claude-3-opus-20240229",
      sonnet: "claude-3-sonnet-20240229"
    }.freeze

    def initialize(api_key, model = :opus)
      super(api_key)
      @model = MODELS[model] || raise(ArgumentError, "Modèle Claude non supporté: #{model}")
    end

    def analyze_chart(chart_data)
      response = HTTParty.post(
        "https://api.anthropic.com/v1/messages",
        headers: {
          "x-api-key" => @api_key,
          "anthropic-version" => "2023-06-01",
          "content-type" => "application/json"
        },
        body: {
          model: @model,
          max_tokens: 1000,
          temperature: 0.3,
          messages: [
            {
              role: "user",
              content: format_prompt(chart_data)
            }
          ]
        }.to_json
      )

      return nil unless response.success?
      process_response(JSON.parse(response.body))
    end

    private

    def format_prompt(chart_data)
      format_base_prompt + "\n\nDonnées du graphique :\n#{chart_data.to_json}"
    end

    def process_response(response)
      content = response.dig("content", 0, "text")
      return nil unless content

      {
        confidence_score: extract_confidence_score(content),
        analysis: extract_analysis(content),
        raw_response: content
      }
    end

    def extract_confidence_score(content)
      content.match(/score de confiance[:\s]+(\d+)/i)&.[](1)&.to_i || 0
    end

    def extract_analysis(content)
      {
        trend_strength: extract_section(content, "force de la tendance"),
        support_resistance: extract_section(content, "support et résistance"),
        pattern_recognition: extract_section(content, "reconnaissance des patterns"),
        volume_analysis: extract_section(content, "analyse du volume"),
        risk_assessment: extract_section(content, "évaluation du risque"),
        recommendations: extract_section(content, "recommandations")
      }
    end
  end

  def initialize(provider = :chatgpt, model = nil)
    @provider = case provider
    when :chatgpt
                  ChatGptProvider.new(ENV["OPENAI_API_KEY"])
    when :claude
                  ClaudeProvider.new(ENV["ANTHROPIC_API_KEY"], model || :opus)
    else
                  raise ArgumentError, "Provider non supporté: #{provider}"
    end
  end

  def analyze_chart(chart_data)
    @provider.analyze_chart(chart_data)
  end
end
