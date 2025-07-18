defmodule SampleApp do
  @moduledoc """
  Sample application for testing Drops.Relation schema generation.
  """

  use Application

  def start(_type, _args) do
    children = [
      SampleApp.Repo
    ]

    opts = [strategy: :one_for_one, name: SampleApp.Supervisor]

    pid = Supervisor.start_link(children, opts)

    Drops.Relation.Cache.warm_up(SampleApp.Repo, ["users"])

    pid
  end

  def view_module({relation, name}) do
    Module.concat([
      SampleApp,
      Atom.to_string(relation) |> String.split(".") |> List.last(),
      Views,
      Macro.camelize(Atom.to_string(name))
    ])
  end
end
