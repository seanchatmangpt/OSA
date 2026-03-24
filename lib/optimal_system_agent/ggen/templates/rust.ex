defmodule OptimalSystemAgent.Ggen.Templates.Rust do
  @moduledoc """
  Fortune 5 Layer 4: Rust Project Template Handler

  Generates Rust crate structure from ODCS specification with proper Cargo.toml,
  source files, and build configuration.

  Signal Theory: S=(code,spec,inform,elixir,module)
  """

  require Logger

  @doc """
  Render Rust template

  Generates:
  - Cargo.toml - Rust package manifest
  - src/lib.rs - Library root with documentation
  - src/main.rs - Executable entry point
  - tests/integration_test.rs - Test structure
  - .gitignore - Rust-specific ignore rules

  Required variables:
    - crate_name: name of the Rust crate
    - edition: Rust edition (2015, 2018, 2021)

  Optional variables:
    - authors: list of authors
    - license: license type (MIT, Apache-2.0, etc.)
    - description: crate description
    - dependencies: map of dependency names to versions
  """
  def render(_template, variables) do
    crate_name = Map.fetch!(variables, "crate_name")
    edition = Map.get(variables, "edition", "2021")
    authors = Map.get(variables, "authors", ["Your Name <your@email.com>"])
    license = Map.get(variables, "license", "MIT")
    description = Map.get(variables, "description", "")
    dependencies = Map.get(variables, "dependencies", %{})

    with :ok <- validate_crate_name(crate_name),
         :ok <- validate_edition(edition) do
      files = [
        {"Cargo.toml", cargo_toml(crate_name, edition, authors, license, description, dependencies)},
        {"src/lib.rs", lib_rs(crate_name, description)},
        {"src/main.rs", main_rs(crate_name)},
        {"tests/integration_test.rs", integration_test(crate_name)},
        {".gitignore", gitignore()},
        {"README.md", readme(crate_name, description)}
      ]

      {:ok, files}
    end
  end

  # Private

  defp validate_crate_name(name) do
    if String.match?(name, ~r/^[a-z_][a-z0-9_]*$/) do
      :ok
    else
      {:error, "Crate name must be lowercase alphanumeric with underscores: #{name}"}
    end
  end

  defp validate_edition(edition) do
    if edition in ["2015", "2018", "2021"] do
      :ok
    else
      {:error, "Invalid Rust edition: #{edition}"}
    end
  end

  defp cargo_toml(crate_name, edition, authors, license, description, dependencies) do
    authors_str =
      authors
      |> (fn a -> if is_list(a), do: a, else: [a] end).()
      |> Enum.map(&"\"#{&1}\"")
      |> Enum.join(", ")

    deps_str =
      dependencies
      |> Map.to_list()
      |> Enum.map(fn {name, version} -> "#{name} = \"#{version}\"" end)
      |> Enum.join("\n")
      |> then(fn s -> if String.length(s) > 0, do: "\n" <> s, else: s end)

    """
    [package]
    name = "#{crate_name}"
    version = "0.1.0"
    edition = "#{edition}"
    authors = [#{authors_str}]
    description = "#{description}"
    license = "#{license}"
    repository = ""
    readme = "README.md"

    [lib]
    name = "#{String.replace(crate_name, "-", "_")}"
    path = "src/lib.rs"

    [[bin]]
    name = "#{crate_name}"
    path = "src/main.rs"

    [dependencies]#{deps_str}

    [dev-dependencies]

    [profile.release]
    opt-level = 3
    lto = true
    codegen-units = 1
    """
  end

  defp lib_rs(crate_name, description) do
    """
    //! #{description}
    //!
    //! This is the main library for the `#{crate_name}` crate.
    //!
    //! # Example
    //!
    //! ```
    //! use #{String.replace(crate_name, "-", "_")}::add;
    //!
    //! let result = add(2, 3);
    //! assert_eq!(result, 5);
    //! ```

    /// Add two numbers together
    ///
    /// # Examples
    ///
    /// ```
    /// use #{String.replace(crate_name, "-", "_")}::add;
    /// assert_eq!(add(2, 3), 5);
    /// ```
    pub fn add(a: i32, b: i32) -> i32 {
        a + b
    }

    /// Subtract two numbers
    ///
    /// # Examples
    ///
    /// ```
    /// use #{String.replace(crate_name, "-", "_")}::subtract;
    /// assert_eq!(subtract(5, 3), 2);
    /// ```
    pub fn subtract(a: i32, b: i32) -> i32 {
        a - b
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_add() {
            assert_eq!(add(2, 2), 4);
            assert_eq!(add(0, 0), 0);
            assert_eq!(add(-1, 1), 0);
        }

        #[test]
        fn test_subtract() {
            assert_eq!(subtract(5, 3), 2);
            assert_eq!(subtract(0, 0), 0);
            assert_eq!(subtract(1, 2), -1);
        }
    }
    """
  end

  defp main_rs(crate_name) do
    safe_name = String.replace(crate_name, "-", "_")

    """
    //! Main entry point for #{crate_name}

    use #{safe_name}::{add, subtract};

    fn main() {
        println!("Welcome to #{crate_name}!");

        let a = 10;
        let b = 5;

        let sum = add(a, b);
        let difference = subtract(a, b);

        println!("{} + {} = {}", a, b, sum);
        println!("{} - {} = {}", a, b, difference);
    }
    """
  end

  defp integration_test(crate_name) do
    safe_name = String.replace(crate_name, "-", "_")

    """
    use #{safe_name}::{add, subtract};

    #[test]
    fn test_basic_operations() {
        assert_eq!(add(10, 5), 15);
        assert_eq!(subtract(10, 5), 5);
    }

    #[test]
    fn test_edge_cases() {
        assert_eq!(add(i32::MAX, -1), i32::MAX - 1);
        assert_eq!(subtract(i32::MIN, -1), i32::MIN + 1);
    }
    """
  end

  defp gitignore do
    """
    # Rust build artifacts
    /target
    Cargo.lock

    # IDE
    .idea/
    .vscode/
    *.swp
    *.swo
    *~
    .DS_Store

    # Dependencies
    /Cargo.lock
    """
  end

  defp readme(crate_name, description) do
    """
    # #{crate_name}

    #{description}

    ## Installation

    Add this to your `Cargo.toml`:

    ```toml
    [dependencies]
    #{crate_name} = "0.1"
    ```

    ## Usage

    ```rust
    use #{String.replace(crate_name, "-", "_")}::add;

    fn main() {
        let result = add(2, 3);
        println!("Result: {}", result);
    }
    ```

    ## License

    This project is licensed under the MIT License.
    """
  end
end
