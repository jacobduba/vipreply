class Example < ApplicationRecord
  attr_accessor :source

  belongs_to :template
  belongs_to :inbox
  belongs_to :embedding

  validates :embedding, presence: true

  THRESHOLD_SIMILARITY = 0.65

  before_validation :ensure_embedding

  # Find all best templates that have a similarity above the threshold.
  def self.find_best_templates(message, inbox, threshold: THRESHOLD_SIMILARITY)
    target_vector = message.generate_embedding

    # Get candidate embeddings (ordered by similarity using inner product)
    candidate_embeddings = Embedding.where(inbox: inbox)
      .nearest_neighbors(:vector, target_vector, distance: "inner_product")
    candidate_embeddings_array = candidate_embeddings.to_a

    # For debugging: output the text and similarity score for each candidate embedding.
    candidate_embeddings_array.each do |embedding|
      similarity = embedding.vector.zip(target_vector).map { |a, b| a * b }.sum
      text = if embedding.embeddable.respond_to?(:body)
        embedding.embeddable.body
      elsif embedding.embeddable.respond_to?(:plaintext)
        embedding.embeddable.plaintext
      else
        "No text available"
      end
      puts "Candidate embedding text: #{text.inspect} - Similarity: #{similarity}"
    end

    # Filter embeddings that have a similarity above the threshold.
    matching_embeddings = candidate_embeddings_array.select do |embedding|
      similarity = embedding.vector.zip(target_vector).map { |a, b| a * b }.sum
      similarity >= threshold
    end

    # Map back to Examples, then to their Templates.
    matching_embeddings.map do |embedding|
      Example.find_by(embedding_id: embedding.id)&.template
    end.compact.uniq
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
end
