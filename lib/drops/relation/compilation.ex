defmodule Drops.Relation.Compilation do
  alias Drops.Relation.Config

  defmodule Macros.Schema do
    defstruct [:name, block: nil, fields: nil, opts: [], infer: true]

    def new(name) when is_binary(name) do
      %Macros.Schema{name: name}
    end

    def new(fields, opts) when is_list(fields) do
      %Macros.Schema{name: nil, fields: fields, opts: opts}
    end

    def new(name, opts) when is_binary(name) and is_list(opts) do
      opts = Keyword.delete(opts, :do)
      infer = Keyword.get(opts, :infer, true)

      %{new(name) | opts: opts, infer: infer}
    end

    def new(name, opts, block) when is_binary(name) and is_list(opts) do
      %{new(name, opts) | block: block}
    end
  end

  defmodule Macros.View do
    defstruct [:name, :block]

    def new(name, block) when is_atom(name) and is_tuple(block) do
      %Macros.View{name: name, block: block}
    end
  end

  defmodule Macros.Derive do
    defstruct [:block]

    def new(block) when is_tuple(block) do
      %Macros.Derive{block: block}
    end
  end

  defmodule Context do
    defstruct [:relation, :config, :schema, views: [], derive: nil]

    def new(relation, config) do
      %Context{relation: relation, config: Config.persist!(config)}
    end

    def update(module, key, args) do
      apply(__MODULE__, key, [context(module), args])
    end

    def schema(context, args) do
      %{context | schema: apply(Macros.Schema, :new, args)}
    end

    def view(context, args) do
      %{context | views: context.views ++ [apply(Macros.View, :new, args)]}
    end

    def derive(context, args) do
      %{context | derive: apply(Macros.Derive, :new, args)}
    end

    def config(relation, key, default \\ nil) do
      case Config.get(key, default) do
        fun when is_function(fun, 1) ->
          fun.(relation)

        other ->
          other
      end
    end

    def get(module, key), do: Map.get(context(module), key)

    defp context(module), do: Module.get_attribute(module, :context)
  end
end
