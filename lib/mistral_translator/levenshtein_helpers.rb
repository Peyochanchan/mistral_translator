# frozen_string_literal: true

module MistralTranslator
  module LevenshteinHelpers
    class << self
      def levenshtein_distance(str1, str2)
        return str2.length if str1.empty?
        return str1.length if str2.empty?

        matrix = initialize_levenshtein_matrix(str1, str2)
        fill_levenshtein_matrix(matrix, str1, str2)
        matrix[str1.length][str2.length]
      end

      def initialize_levenshtein_matrix(str1, str2)
        matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }
        (0..str1.length).each { |i| matrix[i][0] = i }
        (0..str2.length).each { |j| matrix[0][j] = j }
        matrix
      end

      def fill_levenshtein_matrix(matrix, str1, str2)
        (1..str1.length).each do |i|
          (1..str2.length).each do |j|
            cost = str1[i - 1] == str2[j - 1] ? 0 : 1
            matrix[i][j] = calculate_minimum_cost(matrix, i, j, cost)
          end
        end
      end

      def calculate_minimum_cost(matrix, row_idx, col_idx, cost)
        [
          matrix[row_idx - 1][col_idx] + 1,     # deletion
          matrix[row_idx][col_idx - 1] + 1,     # insertion
          matrix[row_idx - 1][col_idx - 1] + cost # substitution
        ].min
      end
    end
  end
end
