class Example < ApplicationRecord
  # attr_accessor :source

  belongs_to :template
  belongs_to :inbox
  belongs_to :source, polymorphic: true
  belongs_to :embedding, optional: true

  validates :embedding, presence: true

  THRESHOLD_SIMILARITY = 0.7

  before_validation :ensure_embedding
  before_destroy :destroy_source_if_example_message

  # Find all best templates that have a similarity above the threshold.
  def self.find_best_templates(message, inbox, base_threshold: 0.67, log_multiplier: 0.07)    # Print the message being embedded.
    puts "Message: #{message}"

    target_vector = message.generate_embedding
    target_vector_literal = ActiveRecord::Base.connection.quote("[#{target_vector.join(",")}]")

    # Compute similarity using the pgvector inner product operator (<#>)
    # and multiply by -1 so that higher similarity appears as a larger positive number.
    similarity_expr = "(-1 * (embeddings.vector <#> #{target_vector_literal}::vector))"

    # Join embeddings -> examples -> templates.
    # Instead of DISTINCT ON, we group by template so we can aggregate
    # (using MAX) the similarity across multiple examples.
    candidate_templates = Embedding
      .joins("JOIN examples ON examples.embedding_id = embeddings.id")
      .joins("JOIN templates ON templates.id = examples.template_id")
      .where(inbox: inbox)
      .select("templates.id AS template_id, templates.output AS template_text, MAX(#{similarity_expr}) AS similarity")
      .group("templates.id, templates.output")
      .order("similarity DESC")

    candidate_templates.each do |record|
      puts "Template: #{record.template_text.inspect} - Similarity: #{record.similarity}\n"
    end

    # matching_template_ids = candidate_templates.select do |record|
    #   record.similarity.to_f >= base_threshold
    # end.map(&:template_id)

    selected_candidate_templates = []
    if candidate_templates.any? && candidate_templates.first.similarity.to_f >= base_threshold
      # Always select the top candidate if it meets the base_threshold.
      selected_candidate_templates << candidate_templates.first

      # For subsequent candidates, use a dynamic threshold.
      candidate_templates[1..-1].each_with_index do |candidate, index|
        # Candidate rank: top candidate is rank 1, so these start at rank 2.
        candidate_rank = index + 2
        dynamic_threshold = base_threshold + (log_multiplier * Math.log(candidate_rank))
        sim = candidate.similarity.to_f
        if sim >= dynamic_threshold
          selected_candidate_templates << candidate
        else
          puts "Candidate at rank #{candidate_rank} with similarity #{sim} did not meet the dynamic threshold #{dynamic_threshold}."
        end
      end
    else
      puts "\nNo candidate met the base threshold of #{base_threshold}.\n"
    end

    puts "\n\nSelected candidate templates:"
    selected_candidate_templates.each do |record|
      puts "Template: #{record.template_text.inspect} - Similarity: #{record.similarity}\n"
    end

    matching_template_ids = selected_candidate_templates.map(&:template_id)
    Template.where(id: matching_template_ids)
  end

  private

  # This callback creates the embedding if none is associated.
  def ensure_embedding
    return if embedding.present?

    if source.present? && source.respond_to?(:generate_embedding)
      vector = source.generate_embedding
      self.embedding = Embedding.create!(
        embeddable: source,
        inbox: inbox,
        vector: vector
      )
    else
      errors.add(:base, "No valid source provided for embedding generation")
    end
  end

  # Callback: When an Example is destroyed, if its source is an ExampleMessage, destroy that source.
  def destroy_source_if_example_message
    if source_type == "ExampleMessage" && source.present?
      source.destroy
    end
  end
end
