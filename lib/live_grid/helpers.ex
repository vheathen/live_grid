defmodule LiveGrid.Helpers do
  @app :live_grid

  def app, do: @app

  def get_config(section, key, default \\ nil) do
    app()
    |> Application.get_env(section, [])
    |> Keyword.get(key, default)
  end
end
