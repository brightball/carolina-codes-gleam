import carolina_codes_gleam/catalog
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn unique_preserves_order_test() {
  assert catalog.unique(["elixir", "go", "elixir", "ruby"])
    == ["elixir", "go", "ruby"]
}
