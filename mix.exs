defmodule OMana.MixProject do
  use Mix.Project

  def project do
    [
      app: :o_mana,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    base = [extra_applications: [:logger]]

    if Mix.env() == :test do
      base
    else
      Keyword.put(base, :mod, {OMana.Application, []})
    end
  end

  defp deps, do: []
end
