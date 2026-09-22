.PHONY: test sast audit secrets format check hooks

export PATH := $(HOME)/.local/bin:$(HOME)/.local/share/mise/shims:$(PATH)

# pgo (via pog) depends on opentelemetry_api, an Elixir OTP application.
# gleam test / gleam run -m go_over start that app and need elixir.app on ERL_LIBS.
ELIXIR_LIB := $(shell mise where elixir 2>/dev/null)/lib
ifneq ($(wildcard $(ELIXIR_LIB)/elixir/ebin/elixir.app),)
export ERL_LIBS := $(ELIXIR_LIB)$(if $(ERL_LIBS),:$(ERL_LIBS))
endif

test:
	gleam test

sast:
	./scripts/sast.sh

audit:
	gleam run -m go_over

secrets:
	gitleaks detect --source . --verbose

format:
	gleam format --check

check: format sast audit secrets test

hooks:
	pre-commit install
	git config core.hooksPath .githooks
	gleam run --target erlang -m cactus
