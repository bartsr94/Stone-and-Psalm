## Confirms the GUT 9.6.0 harness itself runs headless under Godot 4.6.1.
## Not a game test — a regression guard on the exact toolchain pairing in CLAUDE.md
## (GUT 9.7.1 is known broken against 4.6.1).
extends GutTest


func test_harness_runs() -> void:
	assert_eq(1 + 1, 2, "GUT can run a basic assertion")
