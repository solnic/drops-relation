defmodule Drops.Relation.Compilers.EctoCompiler do
  @moduledoc """
  Compiler for converting compiled Ecto schema modules to Relation Schema structures.

  This module follows the same pattern as Drops.Relation.Compilers.SchemaCompiler but works with
  compiled Ecto schema modules and uses Ecto's reflection functions to extract schema
  information.

  The compiler is used to infer schema information from custom field definitions
  provided via the `schema` macro in relation modules.

  ## Usage

      # Convert a compiled Ecto schema module to a Relation Schema
      schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, [])

  ## Examples

      iex> schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, [])
      iex> schema.source
      "users"
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey}

  @doc """
  Main entry point for converting compiled Ecto schema module to Relation Schema.

  ## Parameters

  - `schema_module` - A compiled Ecto schema module
  - `opts` - Optional compilation options

  ## Returns

  A Drops.Relation.Schema.t() struct.

  ## Examples

      iex> schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, [])
      iex> %Drops.Relation.Schema{} = schema
  """
  def visit(schema_module, _opts) when is_atom(schema_module) do
    # Ensure the module is loaded and is an Ecto schema
    unless Code.ensure_loaded?(schema_module) and
             function_exported?(schema_module, :__schema__, 1) do
      raise ArgumentError, "Expected compiled Ecto schema module, got: #{inspect(schema_module)}"
    end

    # Extract information using Ecto's reflection functions
    source = String.to_atom(schema_module.__schema__(:source))
    fields = extract_fields_from_schema(schema_module)
    primary_key = extract_primary_key_from_schema(schema_module)

    # For now, we don't handle foreign keys and indices from Ecto schemas
    # These would typically be inferred from associations which we're ignoring for now
    foreign_keys = []
    indices = []

    Schema.new(source, primary_key, foreign_keys, fields, indices)
  end

  def visit(other, _opts) do
    raise ArgumentError, "Expected compiled Ecto schema module, got: #{inspect(other)}"
  end

  # Extract field information from compiled Ecto schema module
  defp extract_fields_from_schema(schema_module) do
    field_names = schema_module.__schema__(:fields)
    # Get default values from the struct
    default_struct = struct(schema_module)

    associations =
      Enum.map(schema_module.__schema__(:associations), fn name ->
        schema_module.__schema__(:association, name)
      end)

    Enum.map(field_names, fn field_name ->
      field_type = schema_module.__schema__(:type, field_name)
      field_source = schema_module.__schema__(:field_source, field_name)
      # Extract default value from the struct
      default_value = Map.get(default_struct, field_name)
      pk = schema_module.__schema__(:primary_key)

      assoc =
        Enum.find(associations, fn assoc ->
          assoc.owner_key == field_name and field_name not in pk
        end)

      foreign_key = if is_nil(assoc), do: false, else: true

      meta = %{
        source: field_source,
        nullable: nil,
        default: default_value,
        check_constraints: [],
        primary_key: field_name in pk,
        foreign_key: foreign_key,
        association: not is_nil(assoc)
      }

      Field.new(field_name, field_type, meta)
    end)
  end

  # Extract primary key information from compiled Ecto schema module
  defp extract_primary_key_from_schema(schema_module) do
    primary_key_fields = schema_module.__schema__(:primary_key)

    # Convert field names to Field structs for the primary key
    pk_field_structs =
      Enum.map(primary_key_fields, fn field_name ->
        field_type = schema_module.__schema__(:type, field_name)
        field_source = schema_module.__schema__(:field_source, field_name)

        meta = %{
          type: field_type,
          source: field_source,
          # Primary key fields are typically not nullable
          nullable: false,
          default: nil,
          check_constraints: [],
          primary_key: true,
          foreign_key: false
        }

        Field.new(field_name, field_type, meta)
      end)

    PrimaryKey.new(pk_field_structs)
  end
end
