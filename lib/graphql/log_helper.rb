# frozen_string_literal: true

require "graphql"
require_relative "log_helper/version"

module Graphql
  class LogHelper
    class << self
      def log_details(request_params)
        definition = parse_query(request_params[:query])&.definitions&.first
        selections = definition&.selections
        return {} if selections.blank?

        variables = request_params[:variables] || {}

        query_params =
          if variables.present? || (definition.respond_to?(:variables) && definition.variables.any?)
            query_params_given_variables(selections, variables)
          else
            query_params_given_no_variables(selections)
          end

        {
          params: to_deep_a(query_params),
          resolvers: resolver_names(selections)
        }
      end

      private

      def query_params_given_variables(selections, variables)
        selections.map do |selection|
          [
            selection.name,
            to_deep_a(variables)
          ]
        end
      end

      def query_params_given_no_variables(selections)
        selections.map { |selection| selection_to_array(selection) }
      end

      def resolver_names(selections)
        selections.map(&:name)
      end

      def selection_to_array(selection)
        [
          selection.name,
          if !selection.respond_to?(:value)
            selection.arguments.map { |arg| selection_to_array(arg) }
          elsif selection.value.respond_to?(:arguments)
            selection.value.arguments.map { |arg| selection_to_array(arg) }
          elsif selection.value.is_a?(GraphQL::Language::Nodes::NullValue)
            nil
          else
            selection.value
          end
        ]
      end

      def parse_query(query)
        return nil if query.blank?

        GraphQL.parse(query)
      rescue GraphQL::ParseError
        nil
      end

      def to_deep_a(hash)
        hash.map { |key, value| [key, value.is_a?(Hash) ? to_deep_a(value) : value] }
      end
    end
  end
end
