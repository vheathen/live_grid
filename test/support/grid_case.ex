defmodule LiveGrid.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  @app :live_grid

  using do
    quote do
      import LiveGrid.Case
    end
  end

  setup _tags do
    current_settings = Application.get_all_env(app())
    on_exit(fn -> Application.put_all_env([{app(), current_settings}]) end)

    :ok
  end

  def app, do: @app

  def configure(key, nil), do: Application.delete_env(app(), key)
  def configure(key, value), do: Application.put_env(app(), key, value)

  def configure(section, key, nil) do
    config =
      app()
      |> Application.get_env(section, [])
      |> Keyword.delete(key)

    Application.put_env(app(), section, config)
  end

  def configure(section, key, value) do
    config =
      app()
      |> Application.get_env(section, [])
      |> Keyword.put(key, value)

    Application.put_env(app(), section, config)
  end
end
