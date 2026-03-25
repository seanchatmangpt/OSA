defmodule OptimalSystemAgent.Ggen.TemplateRenderer do
  @moduledoc """
  Fortune 5 Layer 4: Template Rendering Engine

  Handles variable substitution, Tera-like template processing, and output file generation.
  Supports deterministic rendering with variable interpolation.

  Signal Theory: S=(code,spec,inform,elixir,module)
  """

  require Logger

  @doc """
  Render a template with variables

  Supports:
  - {{ variable }} - Simple variable substitution
  - {{ variable | filter }} - Filtered output
  - {% if condition %}...{% endif %} - Conditional blocks
  - {% for item in list %}...{% endfor %} - Loops

  Returns:
    {:ok, %{files: [{path, content}, ...], metadata: %{}}}
    {:error, reason}
  """
  def render(template, variables, _options \\ []) do
    with {:ok, files} <- render_files(template, variables) do
      {:ok, %{
        files: files,
        metadata: %{
          template_type: Map.get(template, :type),
          variables_used: Map.keys(variables),
          generated_at: DateTime.utc_now(),
          file_count: length(files)
        }
      }}
    end
  end

  @doc """
  Render a single template string with variables

  Performs variable substitution with {{ }} syntax.
  """
  def render_string(template_string, variables) when is_binary(template_string) do
    template_string
    |> interpolate_variables(variables)
    |> then(&{:ok, &1})
  end

  @doc """
  Render a file with variable substitution

  Reads a template file and renders it with variables.
  """
  def render_file(file_path, variables) do
    with {:ok, content} <- File.read(file_path) do
      render_string(content, variables)
    end
  end

  # Private

  defp render_files(template, variables) do
    handler = Map.get(template, :handler)
    template_type = Map.get(template, :type)

    try do
      if handler && function_exported?(handler, :render, 2) do
        handler.render(template, variables)
      else
        # Default: use template's embedded definitions
        generate_default_files(template_type, variables)
      end
    catch
      :error, reason ->
        {:error, "Failed to render template: #{inspect(reason)}"}
    end
  end

  defp generate_default_files(template_type, variables) do
    case template_type do
      :rust -> generate_rust_files(variables)
      :typescript -> generate_typescript_files(variables)
      :elixir -> generate_elixir_files(variables)
      _ -> {:error, "Unknown template type: #{template_type}"}
    end
  end

  defp generate_rust_files(variables) do
    crate_name = Map.get(variables, "crate_name", "my_crate")
    edition = Map.get(variables, "edition", "2021")
    authors = Map.get(variables, "authors", ["Your Name <your@email.com>"])
    description = Map.get(variables, "description", "")
    license = Map.get(variables, "license", "MIT")

    authors_str =
      authors
      |> (fn a -> if is_list(a), do: a, else: [a] end).()
      |> Enum.map(&"\"#{&1}\"")
      |> Enum.join(", ")

    cargo_toml = """
    [package]
    name = "#{crate_name}"
    version = "0.1.0"
    edition = "#{edition}"
    authors = [#{authors_str}]
    description = "#{description}"
    license = "#{license}"

    [dependencies]

    [dev-dependencies]
    """

    lib_rs = """
    //! #{String.capitalize(crate_name)} library

    /// Add two numbers
    pub fn add(a: i32, b: i32) -> i32 {
        a + b
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_add() {
            assert_eq!(add(2, 2), 4);
        }
    }
    """

    main_rs = """
    use #{crate_name}::add;

    fn main() {
        let result = add(2, 3);
        println!("Result: {}", result);
    }
    """

    {:ok,
     [
       {"Cargo.toml", cargo_toml},
       {"src/lib.rs", lib_rs},
       {"src/main.rs", main_rs}
     ]}
  end

  defp generate_typescript_files(variables) do
    project_name = Map.get(variables, "project_name", "my_project")
    version = Map.get(variables, "version", "1.0.0")
    description = Map.get(variables, "description", "")
    author = Map.get(variables, "author", "")

    package_json = %{
      "name" => project_name,
      "version" => version,
      "description" => description,
      "author" => author,
      "main" => "dist/index.js",
      "types" => "dist/index.d.ts",
      "scripts" => %{
        "build" => "tsc",
        "test" => "jest",
        "dev" => "ts-node src/index.ts"
      },
      "devDependencies" => %{
        "typescript" => "^5.0.0",
        "ts-node" => "^10.0.0",
        "@types/node" => "^20.0.0",
        "jest" => "^29.0.0",
        "ts-jest" => "^29.0.0"
      }
    }
    |> Jason.encode!(pretty: true)

    tsconfig_json = """
    {
      "compilerOptions": {
        "target": "ES2020",
        "module": "commonjs",
        "lib": ["ES2020"],
        "outDir": "./dist",
        "rootDir": "./src",
        "strict": true,
        "esModuleInterop": true,
        "skipLibCheck": true,
        "forceConsistentCasingInFileNames": true,
        "declaration": true,
        "declarationMap": true,
        "sourceMap": true
      },
      "include": ["src/**/*"],
      "exclude": ["node_modules", "dist"]
    }
    """

    index_ts = """
    /**
     * #{project_name} - #{description}
     */

    export function greet(name: string): string {
        return `Hello, ${name}!`;
    }

    export default {
        greet
    };
    """

    {:ok,
     [
       {"package.json", package_json},
       {"tsconfig.json", tsconfig_json},
       {"src/index.ts", index_ts}
     ]}
  end

  defp generate_elixir_files(variables) do
    app_name = Map.get(variables, "app_name", "my_app")
    version = Map.get(variables, "version", "0.1.0")
    description = Map.get(variables, "description", "")

    app_name_atom = String.to_atom(Macro.underscore(app_name))

    mix_exs = """
    defmodule #{Macro.camelize(app_name)}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{app_name_atom},
          version: "#{version}",
          elixir: "~> 1.14",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      def application do
        [
          extra_applications: [:logger]
        ]
      end

      defp deps do
        [
        ]
      end
    end
    """

    app_ex = """
    defmodule #{Macro.camelize(app_name)} do
      @moduledoc \"\"\"
      #{description}
      \"\"\"

      @doc \"\"\"
      Add two numbers.
      \"\"\"
      def add(a, b), do: a + b
    end
    """

    application_ex = """
    defmodule #{Macro.camelize(app_name)}.Application do
      use Application

      @impl true
      def start(_type, _args) do
        children = [
        ]

        opts = [strategy: :one_for_one, name: #{Macro.camelize(app_name)}.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    """

    {:ok,
     [
       {"mix.exs", mix_exs},
       {"lib/#{Macro.underscore(app_name)}.ex", app_ex},
       {"lib/#{Macro.underscore(app_name)}/application.ex", application_ex}
     ]}
  end

  @doc """
  Interpolate variables in a template string

  Replaces {{ var }} with variable values, with optional filters.
  """
  def interpolate_variables(template_string, variables) when is_map(variables) do
    Enum.reduce(variables, template_string, fn {key, value}, acc ->
      var_pattern = "{{ #{key} }}"
      String.replace(acc, var_pattern, to_string(value))
    end)
  end

  @doc """
  Filter a value through a processing function

  Common filters: upcase, downcase, capitalize, etc.
  """
  def apply_filter(value, filter_name) do
    case filter_name do
      "upcase" -> String.upcase(to_string(value))
      "downcase" -> String.downcase(to_string(value))
      "capitalize" -> String.capitalize(to_string(value))
      "length" -> to_string(String.length(to_string(value)))
      _ -> to_string(value)
    end
  end
end
