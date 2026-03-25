defmodule OptimalSystemAgent.Ggen.Templates.Elixir do
  @moduledoc """
  Fortune 5 Layer 4: Elixir Project Template Handler

  Generates Elixir project structure from ODCS specification with proper
  Mix configuration, supervision trees, and test infrastructure.

  Signal Theory: S=(code,spec,inform,elixir,module)
  """

  require Logger

  @doc """
  Render Elixir template

  Generates:
  - mix.exs - Mix project configuration
  - lib/app.ex - Main module with business logic
  - lib/app/application.ex - Application callback
  - test/app_test.exs - Test suite
  - .gitignore - Elixir specific rules

  Required variables:
    - app_name: name of the Elixir app

  Optional variables:
    - version: version number (default: 0.1.0)
    - description: project description
    - elixir_version: required Elixir version (default: ~> 1.14)
  """
  def render(_template, variables) do
    app_name = Map.fetch!(variables, "app_name")
    version = Map.get(variables, "version", "0.1.0")
    description = Map.get(variables, "description", "")
    elixir_version = Map.get(variables, "elixir_version", "~> 1.14")

    with :ok <- validate_app_name(app_name) do
      safe_name = Macro.underscore(app_name)
      camel_name = Macro.camelize(app_name)
      atom_name = String.to_atom(safe_name)

      files = [
        {"mix.exs", mix_exs(camel_name, atom_name, version, description, elixir_version)},
        {"lib/#{safe_name}.ex", main_module(camel_name, description)},
        {"lib/#{safe_name}/application.ex", application_module(camel_name, atom_name)},
        {"test/#{safe_name}_test.exs", test_module(camel_name)},
        {".gitignore", gitignore()},
        {"README.md", readme(camel_name, description)},
        {".formatter.exs", formatter_config()}
      ]

      {:ok, files}
    end
  end

  # Private

  defp validate_app_name(name) do
    if String.match?(name, ~r/^[a-zA-Z][a-zA-Z0-9_]*$/) do
      :ok
    else
      {:error, "App name must start with a letter and contain only alphanumerics and underscores: #{name}"}
    end
  end

  defp mix_exs(camel_name, atom_name, version, description, elixir_version) do
    """
    defmodule #{camel_name}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{atom_name},
          version: "#{version}",
          elixir: "#{elixir_version}",
          start_permanent: Mix.env() == :prod,
          description: "#{description}",
          package: package(),
          deps: deps(),
          # Test coverage
          test_coverage: [tool: ExCoveralls],
          preferred_cli_env: [
            coveralls: :test,
            "coveralls.detail": :test,
            "coveralls.post": :test,
            "coveralls.html": :test
          ]
        ]
      end

      def application do
        [
          extra_applications: [:logger],
          mod: {#{camel_name}.Application, []}
        ]
      end

      defp deps do
        [
          # Development and testing
          {:ex_doc, "~> 0.30", only: :dev, runtime: false},
          {:excoveralls, "~> 0.17", only: :test},
          {:dialyxir, "~> 1.4", only: :dev, runtime: false},
          {:credo, "~> 1.7", only: :dev, runtime: false}
        ]
      end

      defp package do
        [
          description: "#{description}",
          licenses: ["MIT"],
          links: %{
            "GitHub" => ""
          }
        ]
      end
    end
    """
  end

  defp main_module(camel_name, description) do
    """
    defmodule #{camel_name} do
      @moduledoc \"\"\"
      #{description}

      This module provides the main API for #{camel_name}.

      ## Examples

          iex> #{camel_name}.add(2, 3)
          5

          iex> #{camel_name}.greet("World")
          "Hello, World!"
      \"\"\"

      @doc \"\"\"
      Add two numbers together.

      ## Parameters
        - a: first number
        - b: second number

      ## Returns
        The sum of a and b

      ## Examples
          iex> #{camel_name}.add(2, 3)
          5

          iex> #{camel_name}.add(-1, 1)
          0
      \"\"\"
      def add(a, b) when is_number(a) and is_number(b) do
        a + b
      end

      @doc \"\"\"
      Greet someone by name.

      ## Parameters
        - name: the name of the person to greet

      ## Returns
        A greeting message

      ## Examples
          iex> #{camel_name}.greet("World")
          "Hello, World!"

          iex> #{camel_name}.greet("Alice")
          "Hello, Alice!"
      \"\"\"
      def greet(n) when is_binary(n) do
        "Hello, " <> n <> "!"
      end

      @doc \"\"\"
      Get version information.

      ## Returns
        A map with version and description
      \"\"\"
      def version do
        %{
          version: "0.1.0",
          description: "#{description}"
        }
      end
    end
    """
  end

  defp application_module(camel_name, _atom_name) do
    """
    defmodule #{camel_name}.Application do
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
        children = [
          # Workers/Servers go here
        ]

        opts = [
          strategy: :one_for_one,
          name: #{camel_name}.Supervisor
        ]

        Supervisor.start_link(children, opts)
      end
    end
    """
  end

  defp test_module(camel_name) do
    """
    defmodule #{camel_name}Test do
      use ExUnit.Case

      doctest #{camel_name}

      test "add/2 returns the sum" do
        assert #{camel_name}.add(2, 3) == 5
      end

      test "add/2 handles negative numbers" do
        assert #{camel_name}.add(-1, 1) == 0
        assert #{camel_name}.add(-2, -3) == -5
      end

      test "add/2 handles zero" do
        assert #{camel_name}.add(0, 0) == 0
        assert #{camel_name}.add(5, 0) == 5
      end

      test "greet/1 returns a greeting" do
        assert #{camel_name}.greet("World") == "Hello, World!"
        assert #{camel_name}.greet("Alice") == "Hello, Alice!"
      end

      test "greet/1 handles empty strings" do
        assert #{camel_name}.greet("") == "Hello, !"
      end

      test "version/0 returns version info" do
        version = #{camel_name}.version()
        assert is_map(version)
        assert Map.has_key?(version, :version)
        assert Map.has_key?(version, :description)
      end
    end
    """
  end

  defp gitignore do
    """
    # Generated files
    /_build
    /cover
    /deps
    /doc
    erl_crash.dump
    *.ez

    # IDE
    .vscode/
    .idea/
    *.swp
    *.swo
    *~
    .DS_Store

    # Environment
    .env
    .env.local

    # Test coverage
    /coverage

    # Elixir Language Server
    .elixir_ls/

    # Dialyzer
    .dialyzer_plt
    .dialyzer_plt_*

    # Generated documentation
    /doc
    """
  end

  defp formatter_config do
    """
    [
      import_deps: [],
      line_length: 98,
      locals_without_parens: [
        # ExUnit macros
        describe: 2,
        it: 2,
        test: 2,
        assert: 1,
        assert_raise: 3,
        refute: 1
      ]
    ]
    """
  end

  defp readme(camel_name, description) do
    """
    # #{camel_name}

    #{description}

    ## Installation

    If [available in Hex](https://hex.pm/docs/publish), the package can be installed
    by adding `#{String.downcase(camel_name)}` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {#{String.downcase(camel_name)}, "~> 0.1.0"}
      ]
    end
    ```

    ## Usage

    ```elixir
    iex> #{camel_name}.add(2, 3)
    5

    iex> #{camel_name}.greet("World")
    "Hello, World!"
    ```

    ## Development

    Run tests:

    ```bash
    mix test
    ```

    Run with coverage:

    ```bash
    mix test --cover
    ```

    Run code analysis:

    ```bash
    mix credo
    ```

    Generate documentation:

    ```bash
    mix docs
    ```

    ## License

    This project is licensed under the MIT License.
    """
  end
end
